import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var videoEncoder: VideoEncoder?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MemoriaVideo") {
      videoEncoder = VideoEncoder(messenger: registrar.messenger())
    }
  }
}

/// Living Memories encoder: RGBA frames → H.264 with AVAssetWriter, then the
/// music (a PCM WAV) is trimmed, faded out and muxed in as AAC.
/// Same channel contract as the Android VideoEncoder.kt.
final class VideoEncoder {
  private let channel: FlutterMethodChannel
  private let queue = DispatchQueue(label: "memoria.video")
  private var writer: AVAssetWriter?
  private var input: AVAssetWriterInput?
  private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
  private var width = 0
  private var height = 0
  private var fps: Int32 = 24
  private var frameIndex: Int64 = 0
  private var outPath = ""
  private var videoOnlyURL: URL?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "memoria/video", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      self.queue.async {
        do {
          let value = try self.handle(call)
          DispatchQueue.main.async { result(value) }
        } catch {
          self.release()
          DispatchQueue.main.async {
            result(FlutterError(code: "encoder", message: "\(error)", details: nil))
          }
        }
      }
    }
  }

  private struct EncoderError: Error { let message: String }

  private func handle(_ call: FlutterMethodCall) throws -> Any? {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "start":
      try start(
        path: args["path"] as! String,
        width: args["width"] as! Int,
        height: args["height"] as! Int,
        fps: Int32(args["fps"] as! Int),
        bitrate: args["bitrate"] as! Int)
      return nil
    case "frame":
      try frame((args["rgba"] as! FlutterStandardTypedData).data)
      return nil
    case "finish":
      return try finish(audioPath: args["audio"] as? String)
    case "cancel":
      release()
      return nil
    default:
      return FlutterMethodNotImplemented
    }
  }

  private func start(path: String, width: Int, height: Int, fps: Int32, bitrate: Int) throws {
    release()
    self.width = width
    self.height = height
    self.fps = fps
    frameIndex = 0
    outPath = path
    let url = URL(fileURLWithPath: path + ".video.mp4")
    try? FileManager.default.removeItem(at: url)
    videoOnlyURL = url
    let w = try AVAssetWriter(outputURL: url, fileType: .mp4)
    let settings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: bitrate,
        AVVideoMaxKeyFrameIntervalKey: Int(fps),
      ],
    ]
    let i = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    i.expectsMediaDataInRealTime = false
    let a = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: i,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
      ])
    w.add(i)
    guard w.startWriting() else { throw EncoderError(message: "startWriting failed") }
    w.startSession(atSourceTime: .zero)
    writer = w
    input = i
    adaptor = a
  }

  private func frame(_ rgba: Data) throws {
    guard let input = input, let adaptor = adaptor, let pool = adaptor.pixelBufferPool else {
      throw EncoderError(message: "not started")
    }
    while !input.isReadyForMoreMediaData { usleep(2000) }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
    guard let pb = buffer else { throw EncoderError(message: "no pixel buffer") }
    CVPixelBufferLockBaseAddress(pb, [])
    let dst = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self)
    let stride = CVPixelBufferGetBytesPerRow(pb)
    rgba.withUnsafeBytes { (src: UnsafeRawBufferPointer) in
      let s = src.bindMemory(to: UInt8.self)
      for y in 0..<height {
        let row = dst + y * stride
        let from = y * width * 4
        for x in 0..<width {
          let o = from + x * 4
          row[x * 4] = s[o + 2]  // B
          row[x * 4 + 1] = s[o + 1]  // G
          row[x * 4 + 2] = s[o]  // R
          row[x * 4 + 3] = s[o + 3]  // A
        }
      }
    }
    CVPixelBufferUnlockBaseAddress(pb, [])
    adaptor.append(pb, withPresentationTime: CMTime(value: frameIndex, timescale: fps))
    frameIndex += 1
  }

  private func finish(audioPath: String?) throws -> String {
    guard let writer = writer, let input = input, let videoURL = videoOnlyURL else {
      throw EncoderError(message: "not started")
    }
    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
    self.writer = nil
    self.input = nil
    self.adaptor = nil
    let outURL = URL(fileURLWithPath: outPath)
    try? FileManager.default.removeItem(at: outURL)
    guard let audioPath = audioPath else {
      try FileManager.default.moveItem(at: videoURL, to: outURL)
      return outPath
    }
    let duration = CMTime(value: frameIndex, timescale: fps)
    let video = AVURLAsset(url: videoURL)
    let audio = AVURLAsset(url: URL(fileURLWithPath: audioPath))
    let comp = AVMutableComposition()
    let range = CMTimeRange(start: .zero, duration: duration)
    if let v = video.tracks(withMediaType: .video).first,
      let track = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    {
      try track.insertTimeRange(range, of: v, at: .zero)
    }
    let mix = AVMutableAudioMix()
    if let a = audio.tracks(withMediaType: .audio).first,
      let track = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
    {
      let audioRange = CMTimeRange(start: .zero, duration: min(duration, audio.duration))
      try track.insertTimeRange(audioRange, of: a, at: .zero)
      let params = AVMutableAudioMixInputParameters(track: track)
      let fade = CMTime(seconds: 1.5, preferredTimescale: 600)
      params.setVolumeRamp(
        fromStartVolume: 1, toEndVolume: 0,
        timeRange: CMTimeRange(start: audioRange.end - fade, duration: fade))
      mix.inputParameters = [params]
    }
    guard let export = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else {
      throw EncoderError(message: "no export session")
    }
    export.outputURL = outURL
    export.outputFileType = .mp4
    export.audioMix = mix
    let exported = DispatchSemaphore(value: 0)
    export.exportAsynchronously { exported.signal() }
    exported.wait()
    try? FileManager.default.removeItem(at: videoURL)
    if export.status != .completed {
      throw EncoderError(message: export.error?.localizedDescription ?? "export failed")
    }
    return outPath
  }

  private func release() {
    input?.markAsFinished()
    writer?.cancelWriting()
    writer = nil
    input = nil
    adaptor = nil
  }
}
