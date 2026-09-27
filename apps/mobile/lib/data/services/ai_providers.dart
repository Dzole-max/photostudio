import '../../domain/captions/caption_request.dart';
import '../../domain/captions/fake_caption_writer.dart';
import '../../domain/geo/geo_data.dart';
import '../../domain/model/album.dart';
import '../../domain/model/captions.dart';

/// Title, chapter names and captions (the `ai-captions` edge function).
abstract interface class CaptionProvider {
  Future<CaptionSet> write(CaptionRequest request);

  /// Rewrites one text in another tone (the `ai-rewrite` edge function).
  Future<String> rewrite(String text, Tone tone, String language);
}

/// Occasion guess when rules are inconclusive (the `ai-occasion` edge
/// function), from up to 12 representative thumbnails.
abstract interface class OccasionAiProvider {
  Future<Occasion> guess(List<PhotoRef> representative);
}

class FakeCaptionProvider implements CaptionProvider {
  FakeCaptionProvider(
    this.geo, {
    this.delay = const Duration(milliseconds: 600),
  });

  final GeoData geo;
  final Duration delay;

  @override
  Future<CaptionSet> write(CaptionRequest request) async {
    await Future<void>.delayed(delay);
    return FakeCaptionWriter(geo: geo).write(request);
  }

  @override
  Future<String> rewrite(String text, Tone tone, String language) async {
    await Future<void>.delayed(delay ~/ 2);
    final t = text.trim().replaceAll(RegExp(r'[.…]+$'), '');
    if (t.isEmpty) return t;
    return switch (tone) {
      // Minimal: first clause only.
      Tone.minimal => t.split(RegExp(r'[,;:—–]')).first.trim(),
      // Poetic: an ellipsis lets the line breathe.
      Tone.poetic => '$t…',
      // No exclamation marks outside celebrations (brand voice).
      Tone.playful => '$t.',
      Tone.warm => '$t.',
    };
  }
}

class FakeOccasionAiProvider implements OccasionAiProvider {
  const FakeOccasionAiProvider();

  @override
  Future<Occasion> guess(List<PhotoRef> representative) async => Occasion.other;
}
