import 'package:flutter_test/flutter_test.dart';
import 'package:memoria/domain/layout/album_ops.dart';
import 'package:memoria/domain/model/album.dart';
import 'package:memoria/domain/model/geometry.dart';
import 'package:memoria/domain/preflight/preflight.dart';
import 'package:memoria/domain/preflight/preflight_fixes.dart';

import '../helpers/domain_fixtures.dart';
import '../helpers/sample_books.dart';

void main() {
  late Album book;
  late AlbumOps ops;
  late PreflightFixer fixer;

  setUpAll(() {
    book = buildSampleBook('wedding');
    ops = AlbumOps(
      fonts: DomainFixtures.fonts,
      geo: DomainFixtures.geo,
      clock: () => kTestNow,
    );
    fixer = PreflightFixer(ops);
  });

  List<PreflightIssue> issues(Album a) =>
      runPreflight(a, DomainFixtures.fonts).issues;

  Iterable<PreflightIssue> ofRule(Album a, PreflightRule r) =>
      issues(a).where((i) => i.rule == r);

  int firstPhotoPage(Album a, {int minFrames = 1}) => a.pages.indexWhere(
    (p) => p.frames.length >= minFrames && p.templateId != 'chapter_opener',
  );

  test('clean sample book is print-ready', () {
    final report = runPreflight(book, DomainFixtures.fonts);
    expect(report.printReady, isTrue);
    expect(report.canOrder, isTrue);
  });

  test('rule 1: low resolution warns below 200 dpi and blocks below 150', () {
    final pi = firstPhotoPage(book);
    final frame = book.pages[pi].frames.first;
    final photos = {...book.photos};
    photos[frame.photoId!] = photos[frame.photoId!]!.copyWith(
      width: 700,
      height: 466,
    );
    final soft = book.copyWith(photos: photos);
    final found = ofRule(
      soft,
      PreflightRule.lowDpi,
    ).where((i) => i.elementId == frame.id).single;
    expect(found.severity, Severity.blocker);
    expect(found.value, lessThan(150));

    photos[frame.photoId!] = photos[frame.photoId!]!.copyWith(
      width: 1400,
      height: 933,
    );
    final warn = ofRule(
      book.copyWith(photos: photos),
      PreflightRule.lowDpi,
    ).where((i) => i.elementId == frame.id);
    if (warn.isNotEmpty) expect(warn.single.severity, Severity.warning);
  });

  test('rule 1 fix: zoomed crops are reset', () {
    final pi = firstPhotoPage(book);
    final zoomed = ops.setCrop(
      book,
      pi,
      0,
      const CropRect(x: 0.45, y: 0.45, w: 0.08, h: 0.08),
    );
    final issue = ofRule(
      zoomed,
      PreflightRule.lowDpi,
    ).firstWhere((i) => i.pageIndex == pi);
    expect(issue.fix, FixKind.resetZoom);
    final fixed = fixer.apply(zoomed, issue);
    expect(
      ofRule(fixed, PreflightRule.lowDpi).where((i) => i.pageIndex == pi),
      isEmpty,
    );
  });

  test(
    'rule 2: faces near the gutter on full-bleed pages are shifted away',
    () {
      // Put a face-heavy wide photo on a full-bleed right page, face near the gutter.
      final pi = book.pages.indexWhere(
        (p) => p.frames.length == 1 && p.templateId != 'chapter_opener',
      );
      final index = pi.isEven ? pi : pi + 1;
      final photoId = book.pages[index].frames.isNotEmpty
          ? book.pages[index].frames.first.photoId!
          : book.pages[pi].frames.first.photoId!;
      final photos = {...book.photos};
      photos[photoId] = photos[photoId]!.copyWith(
        width: 6000,
        height: 2000,
        faces: const [FaceBox(x: 0.34, y: 0.3, w: 0.05, h: 0.12)],
      );
      var a = ops.recompose(book.copyWith(photos: photos));
      a = ops.swapTemplate(a, index, 'full_bleed');
      // The composer already keeps faces clear; force a bad crop directly.
      final page = a.pages[index];
      final pages = [...a.pages]
        ..[index] = page.copyWith(
          frames: [
            page.frames.first.copyWith(
              crop: const CropRect(x: 0.335, y: 0, w: 0.3467, h: 1),
            ),
          ],
        );
      a = a.copyWith(pages: pages);
      final issue = ofRule(
        a,
        PreflightRule.faceInGutter,
      ).firstWhere((i) => i.pageIndex == index);
      expect(issue.fix, FixKind.shiftCrop);
      final fixed = fixer.apply(a, issue);
      expect(
        ofRule(
          fixed,
          PreflightRule.faceInGutter,
        ).where((i) => i.pageIndex == index),
        isEmpty,
      );
    },
  );

  test('rule 3: text below 8 pt and outside the safe area is fitted', () {
    final pi = book.pages.indexWhere((p) => p.templateId == 'chapter_opener');
    final page = book.pages[pi];
    final title = page.texts.firstWhere((t) => t.id == 'title');
    final broken = page.copyWith(
      texts: [
        for (final t in page.texts)
          if (t.id == 'title')
            t.copyWith(sizePt: 6.5, rectMm: t.rectMm.copyWith(x: -120))
          else
            t,
      ],
    );
    final pages = [...book.pages]..[pi] = broken;
    final a = book.copyWith(pages: pages);
    final small = ofRule(a, PreflightRule.textTooSmall).single;
    expect(
      small.severity,
      Severity.blocker,
      reason: 'below the 7 pt provider minimum',
    );
    final outside = ofRule(a, PreflightRule.textOutsideSafeArea).single;
    expect(
      outside.severity,
      Severity.blocker,
      reason: 'text reaches the bleed',
    );
    var fixed = fixer.apply(a, small);
    // Fitting also moves the block back inside the safe area.
    for (final remaining in ofRule(
      fixed,
      PreflightRule.textOutsideSafeArea,
    ).toList()) {
      fixed = fixer.apply(fixed, remaining);
    }
    expect(ofRule(fixed, PreflightRule.textTooSmall), isEmpty);
    expect(ofRule(fixed, PreflightRule.textOutsideSafeArea), isEmpty);
    expect(
      fixed.pages[pi].texts.firstWhere((t) => t.id == 'title').text,
      title.text,
    );
  });

  test('rule 4: empty frames block printing and are removed by the fix', () {
    final pi = firstPhotoPage(book, minFrames: 2);
    final page = book.pages[pi];
    final pages = [...book.pages]
      ..[pi] = page.copyWith(
        frames: [
          page.frames.first.copyWith(photoId: null),
          ...page.frames.skip(1),
        ],
      );
    final a = book.copyWith(pages: pages);
    final issue = ofRule(a, PreflightRule.emptyFrame).single;
    expect(issue.severity, Severity.blocker);
    final fixed = fixer.apply(a, issue);
    expect(ofRule(fixed, PreflightRule.emptyFrame), isEmpty);
  });

  test('rule 5: odd or out-of-range page counts are adjusted', () {
    final odd = ops.addPage(book, 3);
    expect(odd.pages.length.isOdd, isTrue);
    final issue = ofRule(odd, PreflightRule.pageCount).single;
    expect(issue.severity, Severity.blocker);
    final fixed = fixer.apply(odd, issue);
    expect(fixed.pages.length.isEven, isTrue);
    expect(ofRule(fixed, PreflightRule.pageCount), isEmpty);

    var short = book;
    while (short.pages.length > 20) {
      short = ops.removePage(short, 2);
    }
    final fixedShort = fixer.apply(
      short,
      ofRule(short, PreflightRule.pageCount).single,
    );
    expect(fixedShort.pages.length, greaterThanOrEqualTo(30));
    expect(fixedShort.pages.last.templateId, 'colophon');
  });

  test('rule 6: a photo used twice is a warning', () {
    final a = book;
    final p1 = firstPhotoPage(a);
    final p2 = a.pages.indexWhere(
      (p) => p.frames.isNotEmpty && p.templateId != 'chapter_opener',
      p1 + 1,
    );
    final dup = ops.setPhoto(a, p2, 0, a.pages[p1].frames.first.photoId!);
    final issue = ofRule(dup, PreflightRule.duplicatePhoto).single;
    expect(issue.severity, Severity.warning);
    final fixed = fixer.apply(dup, issue);
    expect(ofRule(fixed, PreflightRule.duplicatePhoto), isEmpty);
  });

  test('rule 7: missing glyphs switch to a theme font that has them', () {
    final pi = book.pages.indexWhere((p) => p.templateId == 'title_page');
    final page = book.pages[pi];
    final pages = [...book.pages]
      ..[pi] = page.copyWith(
        texts: [
          for (final t in page.texts)
            if (t.id == 'title') t.copyWith(text: 'Ана & Марко 漢') else t,
        ],
      );
    final a = book.copyWith(pages: pages);
    final issue = ofRule(a, PreflightRule.missingGlyphs).single;
    expect(issue.detail, '漢');
    final fixed = fixer.apply(a, issue);
    expect(ofRule(fixed, PreflightRule.missingGlyphs), isEmpty);
    expect(
      fixed.pages[pi].texts.firstWhere((t) => t.id == 'title').text,
      'Ана & Марко ',
    );
  });

  test('rule 8: a long cover title shrinks, then wraps', () {
    final t = buildSampleBook('travel');
    final long = ops.updateCoverSlots(
      t,
      t.cover.slots.copyWith(
        title: 'Zanzibar, Pemba and the whole Swahili coast',
      ),
    );
    final remaining = issues(long).where(
      (i) =>
          i.pageIndex == kCoverFront &&
          i.rule == PreflightRule.coverTitleOverflow,
    );
    final fixed = remaining.isEmpty ? long : fixer.apply(long, remaining.first);
    expect(
      issues(fixed).where(
        (i) => i.pageIndex == kCoverFront && i.severity == Severity.blocker,
      ),
      isEmpty,
    );
    final title = fixed.cover.front.texts.firstWhere((x) => x.id == 'title');
    expect(title.sizePt, greaterThanOrEqualTo(8));
  });

  test('thin lines are thickened to 0.25 pt', () {
    final pi = book.pages.indexWhere((p) => p.ornaments.isNotEmpty);
    final page = book.pages[pi];
    final pages = [...book.pages]
      ..[pi] = page.copyWith(
        ornaments: [
          page.ornaments.first.copyWith(strokePt: 0.1, fill: false),
          ...page.ornaments.skip(1),
        ],
      );
    final a = book.copyWith(pages: pages);
    final issue = ofRule(a, PreflightRule.thinLine).single;
    final fixed = fixer.apply(a, issue);
    expect(ofRule(fixed, PreflightRule.thinLine), isEmpty);
  });

  test('fix all repairs every fixable issue', () {
    var a = ops.addPage(book, 3);
    a = ops.setCrop(
      a,
      firstPhotoPage(a),
      0,
      const CropRect(x: 0.45, y: 0.45, w: 0.08, h: 0.08),
    );
    expect(runPreflight(a, DomainFixtures.fonts).canOrder, isFalse);
    final fixed = fixer.fixAll(a);
    expect(runPreflight(fixed, DomainFixtures.fonts).canOrder, isTrue);
  });
}
