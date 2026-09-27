import 'package:flutter_test/flutter_test.dart';
import 'package:memoria/domain/cover/cover_studio.dart';
import 'package:memoria/domain/layout/cover_composer.dart';
import 'package:memoria/domain/layout/page_composer.dart';
import 'package:memoria/domain/model/album.dart';
import 'package:memoria/domain/preflight/preflight.dart';
import 'package:memoria/domain/spec/book_format.dart';
import 'package:memoria/domain/spec/book_strings.dart';
import 'package:memoria/domain/theme/book_theme.dart';

import '../helpers/domain_fixtures.dart';
import '../helpers/sample_books.dart';

void main() {
  List<PhotoRef> included(String set) =>
      DomainFixtures.sample(set).values.where((p) => !p.isExcluded).toList();

  List<CoverVariant> variantsFor(
    String set,
    Occasion o, {
    List<PhotoRef>? photos,
  }) {
    final book = buildSampleBook(set);
    final f = BookFormat.byId(book.formatId);
    return coverVariants(
      occasion: o,
      theme: BookTheme.byId(book.themeId),
      photos: photos ?? included(set),
      coverAspect: f.aspect,
      coverWidthMm: f.trimWMm,
    );
  }

  test('wedding: photo, gold monogram, map with heart, illustrated', () {
    final v = variantsFor('wedding', Occasion.wedding);
    expect(v.map((x) => x.kind), CoverVariantKind.values);
    expect(v.map((x) => x.templateId), [
      'cover_wedding_fullbleed',
      'cover_wedding_monogram',
      'cover_map',
      'cover_illustrated',
    ]);
    expect(v[1].accent, kGoldTone);
    // The illustrated cover is painted from the couple's best portrait.
    final source = DomainFixtures.sample('wedding')[v[3].heroId]!;
    expect(source.faces, hasLength(2));
    expect(v[3].heroId, isNot(v[0].heroId));
  });

  test('travel: stamp roundel instead of monogram, route map', () {
    final v = variantsFor('travel', Occasion.travel);
    expect(v.map((x) => x.templateId), [
      'cover_travel_coordinates',
      'cover_travel_stamp',
      'cover_map',
      'cover_illustrated',
    ]);
    expect(v[3].heroId, isNot(v[0].heroId));
  });

  test('no geotags: no map variant', () {
    final photos = [
      for (final p in included('travel')) p.copyWith(lat: null, lng: null),
    ];
    final v = variantsFor('travel', Occasion.travel, photos: photos);
    expect(v.map((x) => x.kind), isNot(contains(CoverVariantKind.map)));
    expect(v, hasLength(3));
  });

  test('shared slots: title, monogram, coordinates, country', () {
    final w = studioSlots(
      occasion: Occasion.wedding,
      story: const StoryAnswers(names: 'Aleksandar & Elena', place: 'Ohrid'),
      photos: included('wedding'),
      strings: BookStrings('en'),
      geo: DomainFixtures.geo,
    );
    expect(w.title, 'Aleksandar & Elena');
    expect(w.monogram, 'A & E');
    expect(w.location, 'Ohrid');
    final t = studioSlots(
      occasion: Occasion.travel,
      story: const StoryAnswers(title: 'Zanzibar 2026'),
      photos: included('travel'),
      strings: BookStrings('en'),
      geo: DomainFixtures.geo,
      destination: 'Zanzibar',
    );
    expect(t.title, 'Zanzibar');
    expect(t.date, 'July 2026');
    expect(t.details, 'Tanzania');
    expect(t.coordinates, matches(RegExp(r'^\d\.\d{4}° S, 39\.\d{4}° E$')));
  });

  test('every variant composes a cover that passes preflight', () {
    for (final (set, o) in [
      ('wedding', Occasion.wedding),
      ('travel', Occasion.travel),
    ]) {
      final book = buildSampleBook(set);
      final photos = {...book.photos};
      final slots = studioSlots(
        occasion: o,
        story: book.story,
        photos: included(set),
        strings: BookStrings('en'),
        geo: DomainFixtures.geo,
        destination: set == 'travel' ? 'Zanzibar' : null,
      );
      for (final v in variantsFor(set, o)) {
        final env = ComposeEnv(
          format: BookFormat.byId(book.formatId),
          theme: BookTheme.byId(book.themeId),
          accent: v.accent,
          strings: BookStrings('en'),
          fonts: DomainFixtures.fonts,
          photos: photos,
          chapters: book.chapters,
          geo: DomainFixtures.geo,
        );
        final cover = composeCover(
          templateId: v.templateId,
          slots: slots.copyWith(heroPhotoId: v.heroId),
          env: env,
          spineMm: book.cover.spineMm,
        );
        if (v.kind == CoverVariantKind.map) {
          expect(
            cover.front.ornaments.where((o) => o.type == OrnamentType.path),
            isNotEmpty,
          );
        }
        final report = runPreflight(
          book.copyWith(cover: cover),
          DomainFixtures.fonts,
        );
        final coverIssues = report.issues.where(
          (i) => i.pageIndex != null && i.pageIndex! < 0,
        );
        expect(
          coverIssues.map((i) => '${v.templateId}:${i.rule.id}:${i.elementId}'),
          isEmpty,
        );
      }
    }
  });
}
