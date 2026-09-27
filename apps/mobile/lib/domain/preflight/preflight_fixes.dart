import '../layout/album_ops.dart';
import '../layout/page_composer.dart';
import '../layout/smart_crop.dart';
import '../layout/templates.dart';
import '../layout/type_kit.dart';
import '../model/album.dart';
import '../spec/book_format.dart';
import '../text/text_layout.dart';
import '../theme/book_theme.dart';
import 'preflight.dart';

/// One-tap fixes for preflight issues (section 6.5).
class PreflightFixer {
  PreflightFixer(this.ops);

  final AlbumOps ops;

  (int, int)? _frame(Album a, PreflightIssue issue) {
    final p = issue.pageIndex;
    if (p == null || p < 0 || p >= a.pages.length) return null;
    final i = a.pages[p].frames.indexWhere((f) => f.id == issue.elementId);
    return i < 0 ? null : (p, i);
  }

  Album apply(Album a, PreflightIssue issue) {
    switch (issue.fix) {
      case null:
        return a;
      case FixKind.resetZoom:
        final f = _frame(a, issue);
        return f == null ? a : ops.resetCrop(a, f.$1, f.$2);
      case FixKind.smallerFrame:
        final p = issue.pageIndex;
        if (p == null || p < 0) return a;
        return ops.swapTemplate(a, p, 'hero_centered');
      case FixKind.shiftCrop:
        final f = _frame(a, issue);
        if (f == null) return a;
        final (pi, fi) = f;
        final frame = a.pages[pi].frames[fi];
        final photo = a.photos[frame.photoId]!;
        final template = PageTemplate.byId(a.pages[pi].templateId);
        final format = BookFormat.byId(a.formatId);
        final inner = frame.borderMm > 0
            ? frame.rectMm.deflate(frame.borderMm)
            : frame.rectMm;
        final crop = avoidGutter(
          photo,
          frame.crop,
          inner,
          gutterX: format.gutterX(BookFormat.sideOf(pi)),
          minDistMm: template.panorama ? kPanoramaFaceGutterMm : kFaceGutterMm,
          centresOnly: template.panorama,
        );
        return ops.setCrop(a, pi, fi, crop);
      case FixKind.mirrorTemplate:
        final p = issue.pageIndex;
        if (p == null || p < 0) return a;
        final page = a.pages[p];
        return ops.swapTemplate(
          a,
          p,
          page.templateId,
          mirrored: !page.mirrored,
        );
      case FixKind.fitText:
        return _fitText(a, issue);
      case FixKind.removeSlot:
        final f = _frame(a, issue);
        return f == null ? a : ops.removePhoto(a, f.$1, f.$2);
      case FixKind.adjustPageCount:
        return _adjustPageCount(a);
      case FixKind.removeDuplicate:
        final f = _frame(a, issue);
        return f == null ? a : ops.removePhoto(a, f.$1, f.$2);
      case FixKind.fallbackFont:
        return _fallbackFont(a, issue);
      case FixKind.thickenLine:
        return _mapPanel(a, issue.pageIndex, (page) {
          final i = int.tryParse(issue.elementId?.split('_').last ?? '');
          if (i == null || i >= page.ornaments.length) return page;
          final ornaments = [...page.ornaments];
          ornaments[i] = ornaments[i].copyWith(strokePt: kMinStrokePt);
          return page.copyWith(ornaments: ornaments);
        });
    }
  }

  /// Applies every available fix until nothing fixable is left.
  Album fixAll(Album a) {
    var current = a;
    for (var round = 0; round < 6; round++) {
      final issues = runPreflight(
        current,
        ops.fonts,
      ).issues.where((i) => i.fix != null).toList();
      if (issues.isEmpty) break;
      // Structural fixes change page indexes: apply one, then re-run.
      final structural = issues.where(
        (i) => const {
          FixKind.removeSlot,
          FixKind.removeDuplicate,
          FixKind.adjustPageCount,
          FixKind.smallerFrame,
        }.contains(i.fix),
      );
      if (structural.isNotEmpty) {
        current = apply(current, structural.first);
        continue;
      }
      for (final issue in issues) {
        current = apply(current, issue);
      }
    }
    return current;
  }

  Album _mapPanel(Album a, int? pageIndex, BookPage Function(BookPage) f) {
    switch (pageIndex) {
      case null:
        return a;
      case kCoverFront:
        return a.copyWith(cover: a.cover.copyWith(front: f(a.cover.front)));
      case kCoverBack:
        return a.copyWith(cover: a.cover.copyWith(back: f(a.cover.back)));
      case kCoverSpine:
        return a.copyWith(cover: a.cover.copyWith(spine: f(a.cover.spine)));
      default:
        final pages = [...a.pages];
        pages[pageIndex] = f(pages[pageIndex]);
        return a.copyWith(pages: pages);
    }
  }

  Album _fitText(Album a, PreflightIssue issue) {
    final format = BookFormat.byId(a.formatId);
    final kit = TypeKit(BookTheme.byId(a.themeId), format, ops.fonts);
    return _mapPanel(a, issue.pageIndex, (page) {
      final texts = [
        for (final t in page.texts)
          if (t.id != issue.elementId)
            t
          else
            _fitOne(t, a, issue.pageIndex!, kit, format),
      ];
      return page.copyWith(texts: texts);
    });
  }

  TextBlock _fitOne(
    TextBlock t,
    Album a,
    int pageIndex,
    TypeKit kit,
    BookFormat format,
  ) {
    var b = t.sizePt < kMinTextPt ? t.copyWith(sizePt: kMinTextPt) : t;
    // Move the rect inside the safe area.
    final safe = pageIndex >= 0
        ? format.safeArea(BookFormat.sideOf(pageIndex))
        : format.trim.deflate(10);
    if (t.rotationDeg.abs() < 1 && pageIndex != kCoverSpine) {
      final r = b.rectMm;
      final w = r.w > safe.w ? safe.w : r.w;
      final h = r.h > safe.h ? safe.h : r.h;
      final x = r.x.clamp(safe.x, safe.right - w).toDouble();
      final y = r.y.clamp(safe.y, safe.bottom - h).toDouble();
      b = b.copyWith(
        rectMm: r.copyWith(x: x, y: y, w: w, h: h),
      );
    }
    // Shrink to fit (down to the minimum), then allow two lines.
    final lines = b.maxLines ?? 2;
    final size = fitSize(
      b,
      ops.fonts,
      minPt: b.minSizePt ?? kMinTextPt,
      maxPt: b.sizePt,
      maxLines: lines,
    );
    b = b.copyWith(sizePt: size);
    if (layoutTextBlock(b, ops.fonts).overflows && (b.maxLines ?? 1) < 2) {
      b = b.copyWith(maxLines: 2);
    }
    return b;
  }

  Album _fallbackFont(Album a, PreflightIssue issue) {
    final theme = BookTheme.byId(a.themeId);
    final chain = [
      theme.bodyFont,
      theme.displayFont,
      theme.metaFont,
      'Lora',
      'Manrope',
      'Inter',
    ];
    return _mapPanel(a, issue.pageIndex, (page) {
      final texts = [
        for (final t in page.texts)
          if (t.id != issue.elementId)
            t
          else
            () {
              for (final family in chain) {
                final m = ops.fonts.metrics(family, t.weight, italic: t.italic);
                if (m.missing(displayText(t)).isEmpty) {
                  return t.copyWith(fontFamily: family);
                }
              }
              // Nothing can draw it: drop the characters rather than print boxes.
              final m = ops.fonts.metrics(
                t.fontFamily,
                t.weight,
                italic: t.italic,
              );
              final missing = m.missing(displayText(t));
              final cleaned = String.fromCharCodes(
                t.text.runes.where(
                  (r) =>
                      !missing.contains(String.fromCharCode(r).toUpperCase()) &&
                      !missing.contains(String.fromCharCode(r)),
                ),
              );
              return t.copyWith(text: cleaned);
            }(),
      ];
      return page.copyWith(texts: texts);
    });
  }

  Album _adjustPageCount(Album a) {
    final format = BookFormat.byId(a.formatId);
    var current = a;
    var guard = 0;
    while (guard++ < 200) {
      final n = current.pages.length;
      if (n >= format.minPages && n <= format.maxPages && n.isEven) break;
      if (n < format.minPages || (n.isOdd && n < format.maxPages)) {
        // Add a note page before the colophon.
        current = ops.addPage(current, n - 2);
      } else {
        // Remove a note page if any, else the last photo page.
        final notes = current.pages.lastIndexWhere(
          (p) => p.templateId == 'blank_note',
        );
        final idx = notes >= 0
            ? notes
            : current.pages.lastIndexWhere(
                (p) =>
                    PageTemplate.byId(p.templateId).kind == TemplateKind.photo,
              );
        if (idx < 0) break;
        current = ops.removePage(current, idx);
      }
    }
    return current;
  }
}
