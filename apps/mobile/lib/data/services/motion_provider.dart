import '../../domain/memories/trailer.dart';
import '../../domain/model/album.dart';

/// How a hero photo comes alive in Living Memories.
class HeroMotion {
  const HeroMotion({
    required this.photoId,
    required this.focusX,
    required this.focusY,
    required this.focusW,
    required this.focusH,
    this.clipPath,
  });

  final String photoId;

  /// The subject, normalised to the photo: it moves in front of the rest.
  final double focusX;
  final double focusY;
  final double focusW;
  final double focusH;

  /// A generated motion clip (image-to-video model), when a real provider
  /// made one. The trailer uses the parallax when it is null.
  final String? clipPath;
}

/// Brings up to 3 hero photos to life (section 4). A real provider sends
/// the photo to an image-to-video model; the fake builds a two-layer
/// parallax from the face crop.
abstract interface class MotionProvider {
  Future<HeroMotion> animate(PhotoRef photo);
}

class FakeMotionProvider implements MotionProvider {
  const FakeMotionProvider();

  @override
  Future<HeroMotion> animate(PhotoRef photo) async {
    final f = focusOf(photo);
    return HeroMotion(
      photoId: photo.id,
      focusX: f.x,
      focusY: f.y,
      focusW: f.w,
      focusH: f.h,
    );
  }
}
