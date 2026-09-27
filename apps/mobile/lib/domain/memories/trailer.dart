import 'dart:math' as math;

import '../model/album.dart';

/// Living Memories: a 20–30 s trailer of the book. Pure planning — what is
/// shown when; the app paints the frames and encodes the video.

enum TrailerAspect {
  /// Stories, Reels, TikTok.
  portrait(720, 1280),

  /// Feeds and WhatsApp.
  square(720, 720);

  const TrailerAspect(this.width, this.height);

  /// Free export: 720p.
  final int width;
  final int height;
}

enum TrailerSceneKind { cover, opening, spread, hero, closing, endCard }

class TrailerScene {
  const TrailerScene(this.kind, this.start, this.duration, {this.index = 0});

  final TrailerSceneKind kind;
  final double start;
  final double duration;

  /// Spread or hero number within its kind.
  final int index;

  double get end => start + duration;
}

/// Frame rate of the encoded video.
const int kTrailerFps = 24;

/// Scene lengths in seconds.
const double kCoverSeconds = 2.5;
const double kOpeningSeconds = 1.6;
const double kSpreadSeconds = 1.6;
const double kHeroSeconds = 2.3;
const double kClosingSeconds = 2.0;
const double kEndCardSeconds = 2.2;

class TrailerTimeline {
  TrailerTimeline._(this.scenes);

  /// Cover close-up → the book opens → [spreads] spreads turn → [heroes]
  /// photos come alive → the book closes → end card.
  factory TrailerTimeline({required int spreads, required int heroes}) {
    final scenes = <TrailerScene>[];
    var t = 0.0;
    void add(TrailerSceneKind k, double d, [int i = 0]) {
      scenes.add(TrailerScene(k, t, d, index: i));
      t += d;
    }

    add(TrailerSceneKind.cover, kCoverSeconds);
    add(TrailerSceneKind.opening, kOpeningSeconds);
    for (var i = 0; i < spreads; i++) {
      add(TrailerSceneKind.spread, kSpreadSeconds, i);
    }
    for (var i = 0; i < heroes; i++) {
      add(TrailerSceneKind.hero, kHeroSeconds, i);
    }
    add(TrailerSceneKind.closing, kClosingSeconds);
    add(TrailerSceneKind.endCard, kEndCardSeconds);
    return TrailerTimeline._(scenes);
  }

  final List<TrailerScene> scenes;

  double get duration => scenes.last.end;

  int get frameCount => (duration * kTrailerFps).ceil();

  /// The scene at [t] seconds and the progress through it (0..1).
  (TrailerScene, double) at(double t) {
    final c = t.clamp(0.0, duration);
    for (final s in scenes) {
      if (c < s.end || identical(s, scenes.last)) {
        return (s, ((c - s.start) / s.duration).clamp(0.0, 1.0));
      }
    }
    return (scenes.last, 1);
  }
}

/// Spreads worth showing: up to 7 (5–7 in a normal book), spread evenly through the book,
/// preferring ones with photos. Returns spread numbers in book order.
///
/// Spreads follow a real book: spread 0 is the first page alone on the
/// right, then pairs (left = odd page index, right = even).
List<int> pickTrailerSpreads(Album album, {int max = 7}) {
  final pages = album.pages.length;
  final spreadCount = pages <= 1 ? 1 : 1 + (pages - 1 + 1) ~/ 2;
  final candidates = <int>[
    for (var s = 1; s < spreadCount; s++)
      if (_spreadPhotos(album, s) > 0) s,
  ];
  final want = math.min(max, candidates.length);
  final out = <int>[];
  for (var i = 0; i < want; i++) {
    final at = (i * (candidates.length - 1) / math.max(1, want - 1)).round();
    if (!out.contains(candidates[at])) out.add(candidates[at]);
  }
  return out;
}

int _spreadPhotos(Album album, int spread) {
  var n = 0;
  for (final i in [spread * 2 - 1, spread * 2]) {
    if (i >= 0 && i < album.pages.length) {
      n += album.pages[i].frames.where((f) => f.photoId != null).length;
    }
  }
  return n;
}

/// Up to [max] hero photos to bring to life: the best photos in the book,
/// people first, from different chapters, never generated artwork.
List<PhotoRef> pickHeroPhotos(Album album, {int max = 3}) {
  final used = album.usedPhotoIds;
  final chapterOf = <String, String?>{
    for (final p in album.pages)
      for (final f in p.frames)
        if (f.photoId != null) f.photoId!: p.chapterId,
  };
  final pool =
      album.photos.values
          .where((p) => used.contains(p.id) && !p.artwork && !p.isExcluded)
          .toList()
        ..sort((a, b) => _heroScore(b).compareTo(_heroScore(a)));
  final out = <PhotoRef>[];
  final chapters = <String?>{};
  for (final p in pool) {
    if (out.length == max) break;
    final ch = chapterOf[p.id];
    if (ch != null && chapters.contains(ch)) continue;
    chapters.add(ch);
    out.add(p);
  }
  for (final p in pool) {
    if (out.length == max) break;
    if (!out.contains(p)) out.add(p);
  }
  return out;
}

double _heroScore(PhotoRef p) =>
    p.quality.overall +
    (p.faces.isEmpty ? 0 : 0.25) +
    (p.userPinned ? 0.3 : 0) +
    (p.width >= p.height ? 0 : 0.05);

/// Where the eye goes in a photo: the faces, or the middle. Normalised.
({double x, double y, double w, double h}) focusOf(PhotoRef p) {
  if (p.faces.isEmpty) return (x: 0.3, y: 0.28, w: 0.4, h: 0.44);
  var l = 1.0, t = 1.0, r = 0.0, b = 0.0;
  for (final f in p.faces) {
    l = math.min(l, f.x);
    t = math.min(t, f.y);
    r = math.max(r, f.x + f.w);
    b = math.max(b, f.y + f.h);
  }
  // Head and shoulders.
  final w = (r - l) * 1.9, h = (b - t) * 2.4;
  final cx = (l + r) / 2, cy = (t + b) / 2 + (b - t) * 0.35;
  return (
    x: (cx - w / 2).clamp(0.0, 1.0),
    y: (cy - h / 2).clamp(0.0, 1.0),
    w: math.min(w, 1.0),
    h: math.min(h, 1.0),
  );
}

/// Bundled music, chosen by occasion.
enum TrailerTrack {
  warm('assets/music/warm.wav'),
  wander('assets/music/wander.wav'),
  light('assets/music/light.wav');

  const TrailerTrack(this.asset);

  final String asset;

  static TrailerTrack forOccasion(Occasion o) => switch (o) {
    Occasion.wedding => warm,
    Occasion.travel => wander,
    _ => light,
  };
}
