import '../layout/chapters.dart';
import '../model/album.dart';

/// Everything the caption provider needs (section 7.5). No raw images:
/// labels, places and times only, plus optional chapter thumbnails when the
/// user allowed "Use photos to write better captions".
class CaptionRequest {
  const CaptionRequest({
    required this.occasion,
    required this.language,
    required this.story,
    required this.chapters,
    required this.photos,
    this.destination,
    this.thumbnails = const {},
  });

  final Occasion occasion;
  final String language;
  final StoryAnswers story;
  final List<ChapterPlan> chapters;
  final Map<String, PhotoRef> photos;
  final String? destination;

  /// Chapter id → small JPEG (base64), only when the user opted in.
  final Map<String, String> thumbnails;

  Map<String, Object?> toJson() => {
    'occasion': occasion.name,
    'language': language,
    'tone': story.tone.name,
    'answers': story.toJson(),
    'destination': destination,
    'chapters': [
      for (final c in chapters)
        {
          'id': c.chapter.id,
          'title': c.chapter.title,
          'place': c.chapter.placeName,
          'start': c.chapter.dateRange?.start.toIso8601String(),
          'end': c.chapter.dateRange?.end.toIso8601String(),
          'thumbnail': thumbnails[c.chapter.id],
          'photos': [
            for (final id in c.photoIds)
              if (photos[id] case final p?)
                {
                  'id': p.id,
                  'time': p.takenAt?.toIso8601String(),
                  'place': p.placeName,
                  'labels': [for (final l in p.labels.take(5)) l.text],
                  'faces': p.faces.length,
                  'quality': double.parse(p.quality.overall.toStringAsFixed(2)),
                },
          ],
        },
    ],
  };
}

/// Words a caption must never use (section 7.5 prompt rules).
const kClicheList = [
  'unforgettable',
  'magical',
  'memories that last forever',
  'once in a lifetime',
  'fairytale',
  'dream come true',
];

/// Checks the provider's output against the contract's length rules.
bool captionWithinLimits(String text) =>
    text.trim().split(RegExp(r'\s+')).length <= 12;

bool introWithinLimits(String text) =>
    text.trim().isEmpty || text.trim().split(RegExp(r'\s+')).length <= 30;
