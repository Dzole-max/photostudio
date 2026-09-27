import '../layout/page_composer.dart';
import '../layout/smart_crop.dart';
import '../layout/templates.dart';
import '../layout/type_kit.dart';
import '../model/album.dart';
import '../model/geometry.dart';
import '../spec/book_format.dart';
import '../spec/spec_data.dart';
import '../text/font_registry.dart';
import '../text/text_layout.dart';

enum Severity { info, warning, blocker }

/// Rule ids are shared with the TypeScript preflight
/// (services/render/src/preflight) and the fixtures.
enum PreflightRule {
  lowDpi('low_dpi'),
  faceInGutter('face_in_gutter'),
  textOutsideSafeArea('text_outside_safe_area'),
  textTooSmall('text_too_small'),
  textOverflow('text_overflow'),
  emptyFrame('empty_frame'),
  emptyText('empty_text'),
  pageCount('page_count'),
  duplicatePhoto('duplicate_photo'),
  missingGlyphs('missing_glyphs'),
  coverTitleOverflow('cover_title_overflow'),
  thinLine('thin_line');

  const PreflightRule(this.id);

  final String id;
}

enum FixKind {
  resetZoom,
  smallerFrame,
  shiftCrop,
  mirrorTemplate,
  fitText,
  removeSlot,
  adjustPageCount,
  removeDuplicate,
  fallbackFont,
  thickenLine,
}

/// Page index of cover panels in issues.
const int kCoverFront = -1;
const int kCoverBack = -2;
const int kCoverSpine = -3;

/// Hard minimum at which print gets blocked.
const double kBlockDpi = 150;

/// Below this, photos may print soft.
const double kWarnDpi = 200;

/// Thinnest printable line.
const double kMinStrokePt = 0.25;

/// Absolute provider minimum for text.
const double kProviderMinTextPt = 7;

class PreflightIssue {
  const PreflightIssue({
    required this.rule,
    required this.severity,
    required this.pageIndex,
    this.elementId,
    this.areaMm,
    this.fix,
    this.value,
    this.detail,
  });

  final PreflightRule rule;
  final Severity severity;

  /// Inner page index, or [kCoverFront] / [kCoverBack] / [kCoverSpine],
  /// or null for book-wide issues.
  final int? pageIndex;
  final String? elementId;

  /// Problem area on the page, for highlighting.
  final RectMm? areaMm;
  final FixKind? fix;

  /// Measured value (dpi, pt).
  final double? value;
  final String? detail;

  String get key => '${rule.id}:${pageIndex ?? 'book'}:${elementId ?? ''}';
}

class PreflightReport {
  const PreflightReport(this.issues);

  final List<PreflightIssue> issues;

  int count(Severity s) => issues.where((i) => i.severity == s).length;

  bool get printReady =>
      count(Severity.blocker) == 0 && count(Severity.warning) == 0;

  bool get canOrder => count(Severity.blocker) == 0;
}

/// Runs every rule over the album (section 6.5). Pure; mirrored in TS.
PreflightReport runPreflight(Album album, FontRegistry fonts) {
  final format = BookFormat.byId(album.formatId);
  final issues = <PreflightIssue>[];

  void checkFrames(BookPage page, int pageIndex, PageSide? side) {
    final template = PageTemplate.byId(page.templateId);
    for (var i = 0; i < page.frames.length; i++) {
      final f = page.frames[i];
      final inner = f.borderMm > 0 ? f.rectMm.deflate(f.borderMm) : f.rectMm;
      final photoId = f.photoId;
      if (photoId == null) {
        issues.add(
          PreflightIssue(
            rule: PreflightRule.emptyFrame,
            severity: Severity.blocker,
            pageIndex: pageIndex,
            elementId: f.id,
            areaMm: f.rectMm,
            fix: FixKind.removeSlot,
          ),
        );
        continue;
      }
      final photo = album.photos[photoId];
      if (photo == null) continue;
      final dpi = effectiveDpi(photo, f.crop, inner);
      if (dpi < kWarnDpi) {
        final zoomed =
            f.userCrop &&
            smartCrop(photo, inner.aspect).crop.w > f.crop.w + 0.01;
        final canShrink =
            template.isHero || template.id == 'photo_with_text_below';
        issues.add(
          PreflightIssue(
            rule: PreflightRule.lowDpi,
            severity: dpi < kBlockDpi ? Severity.blocker : Severity.warning,
            pageIndex: pageIndex,
            elementId: f.id,
            areaMm: _visible(f.rectMm, format),
            value: dpi,
            fix: zoomed
                ? FixKind.resetZoom
                : (canShrink && page.templateId != 'hero_centered'
                      ? FixKind.smallerFrame
                      : null),
          ),
        );
      }
      if (side != null && photo.faces.isNotEmpty) {
        final gutter = format.gutterX(side);
        final minDist = template.panorama
            ? kPanoramaFaceGutterMm
            : kFaceGutterMm;
        if (faceNearGutter(
          photo,
          f.crop,
          inner,
          gutterX: gutter,
          minDistMm: minDist,
          centresOnly: template.panorama,
        )) {
          final shifted = avoidGutter(
            photo,
            f.crop,
            inner,
            gutterX: gutter,
            minDistMm: minDist,
            centresOnly: template.panorama,
          );
          final shiftWorks = !faceNearGutter(
            photo,
            shifted,
            inner,
            gutterX: gutter,
            minDistMm: minDist,
            centresOnly: template.panorama,
          );
          issues.add(
            PreflightIssue(
              rule: PreflightRule.faceInGutter,
              severity: Severity.warning,
              pageIndex: pageIndex,
              elementId: f.id,
              areaMm: RectMm(
                x: gutter - minDist,
                y: 0,
                w: minDist * 2,
                h: format.trimHMm,
              ),
              fix: shiftWorks
                  ? FixKind.shiftCrop
                  : (_mirrorable(template.id) ? FixKind.mirrorTemplate : null),
            ),
          );
        }
      }
    }
  }

  void checkTexts(
    BookPage page,
    int pageIndex,
    RectMm? safe, {
    bool isCover = false,
  }) {
    for (final t in page.texts) {
      final missing = fonts
          .metrics(t.fontFamily, t.weight, italic: t.italic)
          .missing(displayText(t));
      if (missing.isNotEmpty) {
        issues.add(
          PreflightIssue(
            rule: PreflightRule.missingGlyphs,
            severity: Severity.blocker,
            pageIndex: pageIndex,
            elementId: t.id,
            areaMm: t.rectMm,
            fix: FixKind.fallbackFont,
            detail: missing.join(),
          ),
        );
      }
      if (t.text.trim().isEmpty) {
        if (t.role == TextRole.title && !isCover) {
          issues.add(
            PreflightIssue(
              rule: PreflightRule.emptyText,
              severity: Severity.warning,
              pageIndex: pageIndex,
              elementId: t.id,
              areaMm: t.rectMm,
              fix: null,
            ),
          );
        }
        continue;
      }
      if (t.sizePt < kMinTextPt - 0.01) {
        issues.add(
          PreflightIssue(
            rule: PreflightRule.textTooSmall,
            severity: t.sizePt < kProviderMinTextPt
                ? Severity.blocker
                : Severity.warning,
            pageIndex: pageIndex,
            elementId: t.id,
            areaMm: t.rectMm,
            value: t.sizePt,
            fix: FixKind.fitText,
          ),
        );
      }
      final laid = layoutTextBlock(t, fonts);
      if (laid.overflows || laid.truncated) {
        final coverTitle =
            isCover && t.role == TextRole.title && pageIndex == kCoverFront;
        issues.add(
          PreflightIssue(
            rule: coverTitle
                ? PreflightRule.coverTitleOverflow
                : PreflightRule.textOverflow,
            severity: Severity.warning,
            pageIndex: pageIndex,
            elementId: t.id,
            areaMm: t.rectMm,
            fix: FixKind.fitText,
          ),
        );
      }
      if (safe != null &&
          t.role != TextRole.pageNumber &&
          laid.lines.isNotEmpty) {
        final ink = _inkBounds(t, laid, fonts);
        if (!safe.containsRect(ink, epsilon: 0.2)) {
          final inBleed = !format.trim.containsRect(ink, epsilon: 0.01);
          issues.add(
            PreflightIssue(
              rule: PreflightRule.textOutsideSafeArea,
              severity: inBleed ? Severity.blocker : Severity.warning,
              pageIndex: pageIndex,
              elementId: t.id,
              areaMm: ink,
              fix: FixKind.fitText,
            ),
          );
        }
      }
    }
  }

  void checkLines(BookPage page, int pageIndex) {
    for (var i = 0; i < page.ornaments.length; i++) {
      final o = page.ornaments[i];
      if (o.fill || o.type == OrnamentType.gradient) continue;
      if (o.strokePt < kMinStrokePt - 1e-6) {
        issues.add(
          PreflightIssue(
            rule: PreflightRule.thinLine,
            severity: Severity.warning,
            pageIndex: pageIndex,
            elementId: 'ornament_$i',
            value: o.strokePt,
            fix: FixKind.thickenLine,
          ),
        );
      }
    }
  }

  // Inner pages.
  for (var i = 0; i < album.pages.length; i++) {
    final page = album.pages[i];
    final side = BookFormat.sideOf(i);
    checkFrames(page, i, side);
    checkTexts(page, i, format.safeArea(side));
    checkLines(page, i);
  }

  // Cover (front/back safe area: 10 mm from the trim).
  final coverSafe = format.trim.deflate(kSafeOuterMm);
  checkFrames(album.cover.front, kCoverFront, null);
  checkTexts(album.cover.front, kCoverFront, coverSafe, isCover: true);
  checkTexts(album.cover.back, kCoverBack, coverSafe, isCover: true);
  checkTexts(album.cover.spine, kCoverSpine, null, isCover: true);
  checkLines(album.cover.front, kCoverFront);

  // Page count.
  final n = album.pages.length;
  if (n < format.minPages || n > format.maxPages || n.isOdd) {
    issues.add(
      PreflightIssue(
        rule: PreflightRule.pageCount,
        severity: Severity.blocker,
        pageIndex: null,
        value: n.toDouble(),
        fix: FixKind.adjustPageCount,
      ),
    );
  }

  // Duplicates (inner pages only; the cover may repeat a photo).
  final seen = <String, int>{};
  for (var i = 0; i < album.pages.length; i++) {
    final page = album.pages[i];
    if (page.templateId == 'spread_panorama' && page.mirrored) continue;
    for (final f in page.frames) {
      final id = f.photoId;
      if (id == null) continue;
      if (seen.containsKey(id)) {
        issues.add(
          PreflightIssue(
            rule: PreflightRule.duplicatePhoto,
            severity: Severity.warning,
            pageIndex: i,
            elementId: f.id,
            areaMm: f.rectMm,
            fix: FixKind.removeDuplicate,
            detail: id,
          ),
        );
      } else {
        seen[id] = i;
      }
    }
  }

  issues.sort((a, b) {
    final s = b.severity.index.compareTo(a.severity.index);
    if (s != 0) return s;
    return (a.pageIndex ?? -10).compareTo(b.pageIndex ?? -10);
  });
  return PreflightReport(issues);
}

bool _mirrorable(String templateId) => const {
  'photo_with_text_right',
  'two_offset',
  'three_one_big_two_small',
  'five_mosaic',
}.contains(templateId);

RectMm _visible(RectMm r, BookFormat f) {
  final x0 = r.x.clamp(-kBleedMm, f.trimWMm + kBleedMm);
  final y0 = r.y.clamp(-kBleedMm, f.trimHMm + kBleedMm);
  final x1 = r.right.clamp(-kBleedMm, f.trimWMm + kBleedMm);
  final y1 = r.bottom.clamp(-kBleedMm, f.trimHMm + kBleedMm);
  return RectMm(x: x0, y: y0, w: x1 - x0, h: y1 - y0);
}

/// Bounds of the laid-out lines (not the whole rect).
RectMm _inkBounds(TextBlock t, TextLayoutResult laid, FontRegistry fonts) {
  final m = fonts.metrics(t.fontFamily, t.weight, italic: t.italic);
  final ascent = ptToMm(m.ascender * t.sizePt / m.unitsPerEm);
  final descent = ptToMm(-m.descender * t.sizePt / m.unitsPerEm);
  var x0 = double.infinity, x1 = -double.infinity;
  for (final l in laid.lines) {
    if (l.text.isEmpty) continue;
    if (l.xMm < x0) x0 = l.xMm;
    if (l.xMm + l.widthMm > x1) x1 = l.xMm + l.widthMm;
  }
  if (x0 == double.infinity) return t.rectMm;
  final y0 = laid.lines.first.baselineMm - ascent;
  final y1 = laid.lines.last.baselineMm + descent;
  var r = RectMm(x: x0, y: y0, w: x1 - x0, h: y1 - y0);
  if (t.rotationDeg.abs() > 1) {
    // Rotated (spine) text: rotate the bounds about the block centre.
    final cx = t.rectMm.cx, cy = t.rectMm.cy;
    r = RectMm(
      x: cx - (r.bottom - cy).abs(),
      y: cy - (r.right - cx).abs(),
      w: r.h,
      h: r.w,
    );
  }
  return r;
}
