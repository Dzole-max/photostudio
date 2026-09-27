import 'package:flutter_test/flutter_test.dart';
import 'package:memoria/domain/memories/trailer.dart';
import 'package:memoria/domain/model/album.dart';

import '../helpers/sample_books.dart';

void main() {
  group('timeline', () {
    test('a full book lasts 20–30 s and ends on the end card', () {
      final t = TrailerTimeline(spreads: 6, heroes: 3);
      expect(t.duration, inInclusiveRange(20, 30));
      expect(t.scenes.first.kind, TrailerSceneKind.cover);
      expect(t.scenes.last.kind, TrailerSceneKind.endCard);
      expect(t.frameCount, (t.duration * kTrailerFps).ceil());
    });

    test('scenes are contiguous and at() finds them', () {
      final t = TrailerTimeline(spreads: 5, heroes: 2);
      for (var i = 1; i < t.scenes.length; i++) {
        expect(t.scenes[i].start, closeTo(t.scenes[i - 1].end, 1e-9));
      }
      final (s, p) = t.at(kCoverSeconds + kOpeningSeconds + 0.8);
      expect(s.kind, TrailerSceneKind.spread);
      expect(s.index, 0);
      expect(p, closeTo(0.5, 1e-9));
      expect(t.at(999).$1.kind, TrailerSceneKind.endCard);
      expect(t.at(-1).$1.kind, TrailerSceneKind.cover);
    });
  });

  for (final set in ['wedding', 'travel']) {
    group('sample $set book', () {
      final book = buildSampleBook(set);

      test('5–7 spreads with photos, in book order', () {
        final spreads = pickTrailerSpreads(book);
        expect(spreads.length, inInclusiveRange(5, 7));
        expect([...spreads]..sort(), spreads);
        for (final s in spreads) {
          final pages = [s * 2 - 1, s * 2].where((i) => i < book.pages.length);
          expect(
            pages
                .expand((i) => book.pages[i].frames)
                .any((f) => f.photoId != null),
            isTrue,
          );
        }
      });

      test('up to 3 distinct heroes from the book, people first', () {
        final heroes = pickHeroPhotos(book);
        expect(heroes, hasLength(3));
        expect(heroes.map((h) => h.id).toSet(), hasLength(3));
        for (final h in heroes) {
          expect(book.usedPhotoIds, contains(h.id));
          expect(h.artwork, isFalse);
        }
        if (set == 'wedding') expect(heroes.first.faces, isNotEmpty);
      });
    });
  }

  test('focus covers the faces and stays inside the photo', () {
    const p = PhotoRef(
      id: 'p',
      width: 3000,
      height: 2000,
      faces: [FaceBox(x: 0.4, y: 0.3, w: 0.1, h: 0.15)],
    );
    final f = focusOf(p);
    expect(f.x, lessThanOrEqualTo(0.4));
    expect(f.y, lessThanOrEqualTo(0.3));
    expect(f.x + f.w, greaterThanOrEqualTo(0.5));
    expect(f.x, greaterThanOrEqualTo(0));
    expect(f.w, lessThanOrEqualTo(1));
  });

  test('music follows the occasion', () {
    expect(TrailerTrack.forOccasion(Occasion.wedding), TrailerTrack.warm);
    expect(TrailerTrack.forOccasion(Occasion.travel), TrailerTrack.wander);
    expect(TrailerTrack.forOccasion(Occasion.baby), TrailerTrack.light);
  });
}
