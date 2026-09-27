import 'dart:math' as math;

import '../model/album.dart';
import 'image_stats.dart';

/// Near-duplicates: pHash distance ≤ 8 within 10 minutes (section 7.3).
const int kDuplicateDistance = 8;
const Duration kDuplicateWindow = Duration(minutes: 10);

/// Bursts: within 3 s and pHash distance ≤ 14.
const int kBurstDistance = 14;
const Duration kBurstWindow = Duration(seconds: 3);

/// Photos below this sharpness percentile are set aside...
const double kBlurPercentile = 0.10;

/// ...but only if they are also clearly softer than the batch: raw Laplacian
/// variance under this share of the batch median. Without it a batch of all
/// sharp photos would always lose its bottom 10 %.
const double kBlurMedianShare = 0.12;

/// `overall = 0.40·sharpness + 0.20·exposure + 0.25·eyesOpen + 0.15·faceBonus`.
/// Photos without faces count eyes as open and get no face bonus.
double overallScore({
  required double sharpness,
  required double exposure,
  required List<FaceBox> faces,
}) {
  final eyes = faces.isEmpty
      ? 1.0
      : faces.map((f) => f.eyesOpen ?? 1.0).reduce(math.min);
  final bonus = faces.isEmpty ? 0.0 : faceBonus(faces);
  return 0.40 * sharpness + 0.20 * exposure + 0.25 * eyes + 0.15 * bonus;
}

/// Smiles push the bonus up; an unknown smile counts as 0.6.
double faceBonus(List<FaceBox> faces) {
  if (faces.isEmpty) return 0;
  final smiles = faces.map((f) => f.smile ?? 0.6);
  return (smiles.reduce((a, b) => a + b) / faces.length).clamp(0.0, 1.0);
}

/// Percentile rank (0..1) of each value within the batch.
List<double> percentileRanks(List<double> values) {
  if (values.isEmpty) return const [];
  if (values.length == 1) return const [1];
  final order = List<int>.generate(values.length, (i) => i)
    ..sort((a, b) => values[a].compareTo(values[b]));
  final ranks = List<double>.filled(values.length, 0);
  var i = 0;
  while (i < order.length) {
    var j = i;
    while (j + 1 < order.length && values[order[j + 1]] == values[order[i]]) {
      j++;
    }
    final rank = ((i + j) / 2) / (values.length - 1);
    for (var k = i; k <= j; k++) {
      ranks[order[k]] = rank;
    }
    i = j + 1;
  }
  return ranks;
}

class CurationResult {
  const CurationResult(this.photos);

  final List<PhotoRef> photos;

  List<PhotoRef> get included => photos.where((p) => !p.isExcluded).toList();

  List<PhotoRef> get setAside => photos.where((p) => p.isExcluded).toList();
}

/// Scores, groups bursts and sets aside duplicates and blurry photos.
/// Photos must already carry raw stats (hash, laplacian, exposure, faces).
/// User exclusions and pins are respected.
CurationResult curate(List<PhotoRef> input) {
  final photos = [...input]
    ..sort((a, b) {
      final ta = a.takenAt, tb = b.takenAt;
      if (ta == null || tb == null) return a.id.compareTo(b.id);
      final c = ta.compareTo(tb);
      return c != 0 ? c : a.id.compareTo(b.id);
    });

  // Normalised sharpness and overall score.
  final ranks = percentileRanks([for (final p in photos) p.quality.laplacian]);
  final lapSorted = [for (final p in photos) p.quality.laplacian]..sort();
  final median = lapSorted.isEmpty ? 0.0 : lapSorted[lapSorted.length ~/ 2];
  for (var i = 0; i < photos.length; i++) {
    final p = photos[i];
    final sharp = ranks[i];
    final eyes = p.faces.isEmpty
        ? 1.0
        : p.faces.map((f) => f.eyesOpen ?? 1.0).reduce(math.min);
    photos[i] = p.copyWith(
      quality: p.quality.copyWith(
        sharpness: sharp,
        eyesOpen: eyes,
        faceCount: p.faces.length,
        overall: overallScore(
          sharpness: sharp,
          exposure: p.quality.exposure,
          faces: p.faces,
        ),
      ),
      // Reset automatic exclusions; user exclusions stay.
      isExcluded: p.excludedReason == ExclusionReason.user,
      excludedReason: p.excludedReason == ExclusionReason.user
          ? ExclusionReason.user
          : null,
      burstGroupId: null,
    );
  }

  // Burst grouping: chain photos within 3 s and hash distance ≤ 14.
  var burstIndex = 0;
  for (var i = 0; i < photos.length; i++) {
    if (photos[i].burstGroupId != null) continue;
    final group = [i];
    for (var j = i + 1; j < photos.length; j++) {
      final prev = photos[group.last];
      final t0 = prev.takenAt, t1 = photos[j].takenAt;
      if (t0 == null || t1 == null) break;
      if (t1.difference(t0) > kBurstWindow) break;
      if (hammingDistance(prev.hash, photos[j].hash) <= kBurstDistance) {
        group.add(j);
      }
    }
    if (group.length < 2) continue;
    final id = 'burst${++burstIndex}';
    final best = _best(group, photos);
    for (final k in group) {
      final loser =
          k != best &&
          !photos[k].userPinned &&
          photos[k].excludedReason == null;
      photos[k] = photos[k].copyWith(
        burstGroupId: id,
        isExcluded: photos[k].isExcluded || loser,
        excludedReason: loser
            ? ExclusionReason.burst
            : photos[k].excludedReason,
      );
    }
  }

  // Near-duplicates within 10 minutes: keep the best.
  for (var i = 0; i < photos.length; i++) {
    if (photos[i].isExcluded) continue;
    for (var j = i + 1; j < photos.length; j++) {
      if (photos[j].isExcluded) continue;
      final ti = photos[i].takenAt, tj = photos[j].takenAt;
      if (ti != null &&
          tj != null &&
          tj.difference(ti).abs() > kDuplicateWindow) {
        break;
      }
      if (hammingDistance(photos[i].hash, photos[j].hash) >
          kDuplicateDistance) {
        continue;
      }
      final loser = photos[i].quality.overall >= photos[j].quality.overall
          ? j
          : i;
      if (photos[loser].userPinned) continue;
      photos[loser] = photos[loser].copyWith(
        isExcluded: true,
        excludedReason: ExclusionReason.duplicate,
      );
      if (loser == i) break;
    }
  }

  // Blurry photos.
  for (var i = 0; i < photos.length; i++) {
    final p = photos[i];
    if (p.isExcluded || p.userPinned) continue;
    if (p.quality.sharpness < kBlurPercentile &&
        p.quality.laplacian < median * kBlurMedianShare) {
      photos[i] = p.copyWith(
        isExcluded: true,
        excludedReason: ExclusionReason.blur,
      );
    }
  }
  return CurationResult(photos);
}

int _best(List<int> group, List<PhotoRef> photos) {
  var best = group.first;
  for (final k in group) {
    final p = photos[k], b = photos[best];
    if (p.userPinned && !b.userPinned) {
      best = k;
    } else if (p.userPinned == b.userPinned &&
        p.quality.overall > b.quality.overall) {
      best = k;
    }
  }
  return best;
}
