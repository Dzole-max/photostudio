import 'package:flutter/services.dart';

/// On-device H.264/AAC MP4 encoder (Android MediaCodec + MediaMuxer, iOS
/// AVAssetWriter). Frames are raw RGBA; the audio is a 16-bit PCM WAV file
/// that is trimmed to the video and faded out.
class VideoEncoder {
  static const _channel = MethodChannel('memoria/video');

  Future<void> start({
    required String path,
    required int width,
    required int height,
    required int fps,
    int bitrate = 4000000,
  }) => _channel.invokeMethod('start', {
    'path': path,
    'width': width,
    'height': height,
    'fps': fps,
    'bitrate': bitrate,
  });

  Future<void> addFrame(ByteData rgba) => _channel.invokeMethod('frame', {
    'rgba': rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
  });

  /// Closes the video and muxes [audioWavPath] in; returns the MP4 path.
  Future<String> finish({String? audioWavPath}) async =>
      (await _channel.invokeMethod<String>('finish', {'audio': audioWavPath}))!;

  Future<void> cancel() => _channel.invokeMethod('cancel');
}
