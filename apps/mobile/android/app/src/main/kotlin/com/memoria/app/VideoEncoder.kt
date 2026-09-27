package com.memoria.app

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors

/**
 * Living Memories encoder: RGBA frames → H.264, a PCM WAV → AAC, muxed
 * into one MP4. Work runs on a single background thread.
 */
class VideoEncoder(messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "memoria/video")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private var codec: MediaCodec? = null
    private var muxer: MediaMuxer? = null
    private var track = -1
    private var muxerStarted = false
    private var width = 0
    private var height = 0
    private var fps = 24
    private var frameIndex = 0L
    private var outPath = ""
    private var videoOnlyPath = ""
    private val info = MediaCodec.BufferInfo()

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        worker.execute {
            try {
                val value: Any? = when (call.method) {
                    "start" -> {
                        start(
                            call.argument<String>("path")!!,
                            call.argument<Int>("width")!!,
                            call.argument<Int>("height")!!,
                            call.argument<Int>("fps")!!,
                            call.argument<Int>("bitrate")!!,
                        ); null
                    }
                    "frame" -> { frame(call.argument<ByteArray>("rgba")!!); null }
                    "finish" -> finish(call.argument<String>("audio"))
                    "cancel" -> { release(); null }
                    else -> { main.post { result.notImplemented() }; return@execute }
                }
                main.post { result.success(value) }
            } catch (e: Exception) {
                release()
                main.post { result.error("encoder", e.message, null) }
            }
        }
    }

    private fun start(path: String, w: Int, h: Int, rate: Int, bitrate: Int) {
        release()
        width = w; height = h; fps = rate; frameIndex = 0
        outPath = path
        videoOnlyPath = "$path.video.mp4"
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, w, h).apply {
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible,
            )
            setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
            setInteger(MediaFormat.KEY_FRAME_RATE, rate)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
        codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC).also {
            it.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            it.start()
        }
        muxer = MediaMuxer(videoOnlyPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        track = -1
        muxerStarted = false
    }

    private fun frame(rgba: ByteArray) {
        val c = codec ?: error("not started")
        var index: Int
        while (true) {
            index = c.dequeueInputBuffer(10_000)
            if (index >= 0) break
            drain(false)
        }
        val image = c.getInputImage(index) ?: error("no input image")
        val planes = image.planes
        val y = planes[0]; val u = planes[1]; val v = planes[2]
        val yBuf = y.buffer; val uBuf = u.buffer; val vBuf = v.buffer
        val yRow = y.rowStride; val yPix = y.pixelStride
        val uRow = u.rowStride; val uPix = u.pixelStride
        val vRow = v.rowStride; val vPix = v.pixelStride
        for (row in 0 until height) {
            var src = row * width * 4
            var dst = row * yRow
            val chroma = row % 2 == 0
            val cRowU = (row / 2) * uRow
            val cRowV = (row / 2) * vRow
            for (col in 0 until width) {
                val r = rgba[src].toInt() and 0xFF
                val g = rgba[src + 1].toInt() and 0xFF
                val b = rgba[src + 2].toInt() and 0xFF
                // BT.601 limited range.
                yBuf.put(dst, (((66 * r + 129 * g + 25 * b + 128) shr 8) + 16).toByte())
                if (chroma && col % 2 == 0) {
                    val cu = (((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128).coerceIn(0, 255)
                    val cv = (((112 * r - 94 * g - 18 * b + 128) shr 8) + 128).coerceIn(0, 255)
                    uBuf.put(cRowU + (col / 2) * uPix, cu.toByte())
                    vBuf.put(cRowV + (col / 2) * vPix, cv.toByte())
                }
                src += 4
                dst += yPix
            }
        }
        val pts = frameIndex * 1_000_000L / fps
        c.queueInputBuffer(index, 0, width * height * 3 / 2, pts, 0)
        frameIndex++
        drain(false)
    }

    private fun drain(endOfStream: Boolean) {
        val c = codec ?: return
        val m = muxer ?: return
        while (true) {
            val out = c.dequeueOutputBuffer(info, if (endOfStream) 10_000 else 0)
            when {
                out == MediaCodec.INFO_TRY_AGAIN_LATER -> if (!endOfStream) return
                out == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    track = m.addTrack(c.outputFormat)
                    m.start()
                    muxerStarted = true
                }
                out >= 0 -> {
                    val buf = c.getOutputBuffer(out)!!
                    if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                    if (info.size > 0 && muxerStarted) {
                        buf.position(info.offset)
                        buf.limit(info.offset + info.size)
                        m.writeSampleData(track, buf, info)
                    }
                    c.releaseOutputBuffer(out, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                }
            }
        }
    }

    private fun finish(audioPath: String?): String {
        val c = codec ?: error("not started")
        var index: Int
        while (true) {
            index = c.dequeueInputBuffer(10_000)
            if (index >= 0) break
            drain(false)
        }
        c.queueInputBuffer(index, 0, 0, frameIndex * 1_000_000L / fps, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
        drain(true)
        c.stop(); c.release(); codec = null
        muxer?.stop(); muxer?.release(); muxer = null
        val durationUs = frameIndex * 1_000_000L / fps
        if (audioPath == null) {
            File(videoOnlyPath).renameTo(File(outPath))
        } else {
            muxWithAudio(audioPath, durationUs)
            File(videoOnlyPath).delete()
        }
        return outPath
    }

    private class Sample(val data: ByteArray, val ptsUs: Long, val flags: Int)

    /** Reads a 16-bit PCM WAV, trims it to [durationUs] with fades, encodes AAC. */
    private fun encodeAudio(path: String, durationUs: Long): Pair<MediaFormat, List<Sample>> {
        val raf = RandomAccessFile(path, "r")
        val header = ByteArray(12); raf.readFully(header)
        var channels = 1; var rate = 44100; var bits = 16
        var pcm = ByteArray(0)
        while (raf.filePointer < raf.length()) {
            val id = ByteArray(4); raf.readFully(id)
            val sizeBytes = ByteArray(4); raf.readFully(sizeBytes)
            val size = ByteBuffer.wrap(sizeBytes).order(ByteOrder.LITTLE_ENDIAN).int
            val chunk = ByteArray(size); raf.readFully(chunk)
            if (size % 2 == 1 && raf.filePointer < raf.length()) raf.skipBytes(1)
            when (String(id)) {
                "fmt " -> {
                    val b = ByteBuffer.wrap(chunk).order(ByteOrder.LITTLE_ENDIAN)
                    channels = b.getShort(2).toInt()
                    rate = b.getInt(4)
                    bits = b.getShort(14).toInt()
                }
                "data" -> pcm = chunk
            }
        }
        raf.close()
        require(bits == 16) { "16-bit PCM expected" }
        val frameBytes = 2 * channels
        val totalFrames = minOf(pcm.size / frameBytes, (durationUs * rate / 1_000_000L).toInt())
        val samples = ByteBuffer.wrap(pcm).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
        val fadeIn = rate / 3
        val fadeOut = rate * 3 / 2
        val trimmed = ByteBuffer.allocate(totalFrames * frameBytes).order(ByteOrder.LITTLE_ENDIAN)
        for (i in 0 until totalFrames) {
            val gain = minOf(1.0, i.toDouble() / fadeIn, (totalFrames - i).toDouble() / fadeOut)
            for (ch in 0 until channels) {
                trimmed.putShort((samples.get(i * channels + ch) * gain).toInt().toShort())
            }
        }
        val pcmOut = trimmed.array()

        val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, rate, channels).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, 128_000)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
        }
        val enc = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        enc.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        enc.start()
        val out = mutableListOf<Sample>()
        var outFormat: MediaFormat? = null
        var offset = 0
        var inputDone = false
        val bi = MediaCodec.BufferInfo()
        while (true) {
            if (!inputDone) {
                val i = enc.dequeueInputBuffer(10_000)
                if (i >= 0) {
                    val buf = enc.getInputBuffer(i)!!
                    buf.clear()
                    val n = minOf(buf.capacity(), 8192, pcmOut.size - offset)
                    val pts = (offset / frameBytes).toLong() * 1_000_000L / rate
                    if (n <= 0) {
                        enc.queueInputBuffer(i, 0, 0, pts, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        buf.put(pcmOut, offset, n)
                        enc.queueInputBuffer(i, 0, n, pts, 0)
                        offset += n
                    }
                }
            }
            val o = enc.dequeueOutputBuffer(bi, 10_000)
            if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                outFormat = enc.outputFormat
            } else if (o >= 0) {
                val buf = enc.getOutputBuffer(o)!!
                if (bi.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0 && bi.size > 0) {
                    val data = ByteArray(bi.size)
                    buf.position(bi.offset); buf.get(data)
                    out.add(Sample(data, bi.presentationTimeUs, bi.flags))
                }
                enc.releaseOutputBuffer(o, false)
                if (bi.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
            }
        }
        enc.stop(); enc.release()
        return Pair(outFormat ?: error("no audio format"), out)
    }

    private fun muxWithAudio(audioPath: String, durationUs: Long) {
        val (audioFormat, audio) = encodeAudio(audioPath, durationUs)
        val ex = MediaExtractor()
        ex.setDataSource(videoOnlyPath)
        ex.selectTrack(0)
        val mux = MediaMuxer(outPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val vt = mux.addTrack(ex.getTrackFormat(0))
        val at = mux.addTrack(audioFormat)
        mux.start()
        val buf = ByteBuffer.allocate(4 * 1024 * 1024)
        val bi = MediaCodec.BufferInfo()
        // Interleave by timestamp so players can stream the file.
        var ai = 0
        fun writeAudioUntil(us: Long) {
            while (ai < audio.size && audio[ai].ptsUs <= us) {
                val s = audio[ai++]
                bi.set(0, s.data.size, s.ptsUs, 0)
                mux.writeSampleData(at, ByteBuffer.wrap(s.data), bi)
            }
        }
        while (true) {
            val n = ex.readSampleData(buf, 0)
            if (n < 0) break
            val t = ex.sampleTime
            writeAudioUntil(t)
            val key = ex.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0
            bi.set(0, n, t, if (key) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0)
            mux.writeSampleData(vt, buf, bi)
            ex.advance()
        }
        writeAudioUntil(Long.MAX_VALUE)
        mux.stop(); mux.release(); ex.release()
    }

    private fun release() {
        try { codec?.stop() } catch (_: Exception) {}
        codec?.release(); codec = null
        try { if (muxerStarted) muxer?.stop() } catch (_: Exception) {}
        muxer?.release(); muxer = null
        muxerStarted = false
    }
}
