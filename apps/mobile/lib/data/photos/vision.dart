import 'dart:io';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../../domain/model/album.dart';

class VisionResult {
  const VisionResult({this.faces = const [], this.labels = const []});

  final List<FaceBox> faces;
  final List<PhotoLabel> labels;
}

/// On-device face detection and image labelling (section 7.3 step 4).
abstract interface class Vision {
  Future<VisionResult> analyze(String filePath, int width, int height);

  Future<void> close();
}

/// Used in tests, on desktop and when a photo has no local file.
class NoVision implements Vision {
  const NoVision();

  @override
  Future<VisionResult> analyze(String filePath, int width, int height) async =>
      const VisionResult();

  @override
  Future<void> close() async {}
}

class MlKitVision implements Vision {
  MlKitVision()
    : _faces = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          minFaceSize: 0.05,
        ),
      ),
      _labels = ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: 0.5),
      );

  final FaceDetector _faces;
  final ImageLabeler _labels;

  static bool get supported => Platform.isAndroid || Platform.isIOS;

  @override
  Future<VisionResult> analyze(String filePath, int width, int height) async {
    final input = InputImage.fromFilePath(filePath);
    final faces = await _faces.processImage(input);
    final labels = await _labels.processImage(input);
    labels.sort((a, b) => b.confidence.compareTo(a.confidence));
    return VisionResult(
      faces: [
        for (final f in faces)
          FaceBox(
            x: (f.boundingBox.left / width).clamp(0, 1),
            y: (f.boundingBox.top / height).clamp(0, 1),
            w: (f.boundingBox.width / width).clamp(0, 1),
            h: (f.boundingBox.height / height).clamp(0, 1),
            eyesOpen: _eyes(f),
            smile: f.smilingProbability,
          ),
      ],
      labels: [
        for (final l in labels.take(10))
          PhotoLabel(text: l.label.toLowerCase(), confidence: l.confidence),
      ],
    );
  }

  double? _eyes(Face f) {
    final l = f.leftEyeOpenProbability, r = f.rightEyeOpenProbability;
    if (l == null && r == null) return null;
    return [l, r].whereType<double>().reduce((a, b) => a < b ? a : b);
  }

  @override
  Future<void> close() async {
    await _faces.close();
    await _labels.close();
  }
}
