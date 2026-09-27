import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:memoria/domain/curation/curation.dart';
import 'package:memoria/domain/curation/image_stats.dart';
import 'package:memoria/domain/model/album.dart';

import '../helpers/domain_fixtures.dart';

PhotoRef photo(
  String id, {
  double laplacian = 100,
  double exposure = 1,
  String hash = '0000000000000000',
  DateTime? at,
  List<FaceBox> faces = const [],
  bool pinned = false,
}) => PhotoRef(
  id: id,
  width: 3000,
  height: 2000,
  takenAt: at ?? DateTime.utc(2026, 7, 3, 10),
  hash: hash,
  faces: faces,
  userPinned: pinned,
  quality: QualityScore(laplacian: laplacian, exposure: exposure),
);

void main() {
  group('overall score formula', () {
    test('no faces: eyes count as open, no face bonus', () {
      expect(
        overallScore(sharpness: 1, exposure: 1, faces: const []),
        closeTo(0.85, 1e-9),
      );
      expect(
        overallScore(sharpness: 0.5, exposure: 0.5, faces: const []),
        closeTo(0.2 + 0.1 + 0.25, 1e-9),
      );
    });

    test('faces: closed eyes and smiles move the score', () {
      const open = FaceBox(
        x: 0.1,
        y: 0.1,
        w: 0.1,
        h: 0.1,
        eyesOpen: 1,
        smile: 1,
      );
      const closed = FaceBox(
        x: 0.1,
        y: 0.1,
        w: 0.1,
        h: 0.1,
        eyesOpen: 0,
        smile: 1,
      );
      expect(
        overallScore(sharpness: 1, exposure: 1, faces: const [open]),
        closeTo(1.0, 1e-9),
      );
      expect(
        overallScore(sharpness: 1, exposure: 1, faces: const [open, closed]),
        closeTo(0.75, 1e-9),
      );
      // Unknown smile counts as 0.6.
      const unknown = FaceBox(x: 0, y: 0, w: 0.1, h: 0.1);
      expect(
        overallScore(sharpness: 0, exposure: 0, faces: const [unknown]),
        closeTo(0.25 + 0.15 * 0.6, 1e-9),
      );
    });
  });

  test('percentile ranks handle ties', () {
    expect(percentileRanks([10, 20, 20, 40]), [0, 0.5, 0.5, 1]);
    expect(percentileRanks([5]), [1]);
  });

  group('pHash', () {
    test('sample near-duplicates hash close, unrelated photos far', () {
      final w = DomainFixtures.sample('wedding');
      expect(w['w11']!.hash, hasLength(16));
      expect(
        hammingDistance(w['w11']!.hash, w['w12']!.hash),
        lessThanOrEqualTo(kDuplicateDistance),
      );
      expect(
        hammingDistance(w['w04']!.hash, w['w05']!.hash),
        lessThanOrEqualTo(kBurstDistance),
      );
      expect(
        hammingDistance(w['w01']!.hash, w['w17']!.hash),
        greaterThan(kBurstDistance),
      );
    });

    test('hamming distance counts differing bits', () {
      expect(hammingDistance('0000000000000000', 'ffffffffffffffff'), 64);
      expect(hammingDistance('0000000000000001', '0000000000000003'), 1);
    });

    test('blur lowers the Laplacian variance', () {
      final base = img.Image(width: 256, height: 192);
      for (final p in base) {
        final v = ((p.x ~/ 16) + (p.y ~/ 16)).isEven ? 220 : 40;
        p
          ..r = v
          ..g = v
          ..b = v;
      }
      final sharp = statsFromImage(base);
      final blurred = statsFromImage(img.gaussianBlur(base, radius: 6));
      expect(blurred.laplacian, lessThan(sharp.laplacian * 0.5));
    });

    test('clipped exposure scores low', () {
      final white = Float64List.fromList(List.filled(100, 255));
      final mid = Float64List.fromList(List.filled(100, 128));
      expect(exposureScore(white), 0);
      expect(exposureScore(mid), 1);
    });
  });

  group('curate', () {
    final t0 = DateTime.utc(2026, 7, 3, 10);

    test('burst: keeps the best, sets aside the rest', () {
      final result = curate([
        photo('a', laplacian: 50, hash: '00000000000000ff', at: t0),
        photo(
          'b',
          laplacian: 90,
          hash: '00000000000000fe',
          at: t0.add(const Duration(seconds: 1)),
        ),
        photo(
          'c',
          laplacian: 70,
          hash: '00000000000000fc',
          at: t0.add(const Duration(seconds: 2)),
        ),
        photo(
          'd',
          laplacian: 80,
          hash: 'ffff0000ffff0000',
          at: t0.add(const Duration(hours: 1)),
        ),
      ]);
      final byId = {for (final p in result.photos) p.id: p};
      expect(byId['b']!.isExcluded, isFalse);
      expect(byId['a']!.excludedReason, ExclusionReason.burst);
      expect(byId['c']!.excludedReason, ExclusionReason.burst);
      expect(byId['a']!.burstGroupId, byId['b']!.burstGroupId);
      expect(byId['d']!.isExcluded, isFalse);
    });

    test('near duplicates within 10 minutes keep the best', () {
      final result = curate([
        photo('a', laplacian: 90, hash: 'f0f0f0f0f0f0f0f0', at: t0),
        photo(
          'b',
          laplacian: 50,
          hash: 'f0f0f0f0f0f0f0f1',
          at: t0.add(const Duration(minutes: 5)),
        ),
        photo(
          'c',
          laplacian: 50,
          hash: 'f0f0f0f0f0f0f0f1',
          at: t0.add(const Duration(minutes: 30)),
        ),
      ]);
      final byId = {for (final p in result.photos) p.id: p};
      expect(byId['b']!.excludedReason, ExclusionReason.duplicate);
      expect(
        byId['c']!.isExcluded,
        isFalse,
        reason: 'outside the 10 minute window',
      );
    });

    test(
      'blurry photos are set aside unless pinned; sharp batches lose nothing',
      () {
        final hashes = [
          '1111111111111111',
          '2222222222222222',
          '4444444444444444',
          '8888888888888888',
          'aaaaaaaaaaaaaaaa',
          'cccccccccccccccc',
        ];
        final list = [
          for (var i = 0; i < 6; i++)
            photo(
              'p$i',
              laplacian: 100.0 + i,
              hash: hashes[i],
              at: t0.add(Duration(hours: i)),
            ),
        ];
        expect(curate(list).setAside, isEmpty);
        final withBlur = [
          ...list,
          photo(
            'blur',
            laplacian: 5,
            hash: 'ffffffffffffffff',
            at: t0.add(const Duration(hours: 9)),
          ),
        ];
        expect(curate(withBlur).setAside.map((p) => p.id), ['blur']);
        final pinned = [
          ...list,
          photo(
            'blur',
            laplacian: 5,
            hash: 'ffffffffffffffff',
            at: t0.add(const Duration(hours: 9)),
            pinned: true,
          ),
        ];
        expect(curate(pinned).setAside, isEmpty);
      },
    );

    test('sample sets: bursts, duplicates and blur are found', () {
      final wedding = DomainFixtures.sample('wedding');
      final burst = [wedding['w04']!, wedding['w05']!];
      expect(
        burst.where((p) => p.excludedReason == ExclusionReason.burst),
        hasLength(1),
      );
      expect(burst.first.burstGroupId, isNotNull);
      expect(wedding['w12']!.isExcluded, isTrue);
      expect(wedding['w16']!.excludedReason, ExclusionReason.blur);
      final travel = DomainFixtures.sample('travel');
      expect(
        [travel['t17']!, travel['t23']!].where((p) => p.isExcluded),
        hasLength(1),
      );
      expect(travel['t09']!.isExcluded, isTrue);
      expect(travel['t22']!.excludedReason, ExclusionReason.blur);
      expect(wedding.values.where((p) => p.isExcluded).length, 3);
      expect(travel.values.where((p) => p.isExcluded).length, 3);
    });
  });
}
