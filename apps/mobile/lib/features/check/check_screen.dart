import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/domain_kit.dart';
import '../../data/services/observability.dart';
import '../../data/services/services.dart';
import '../../design/design.dart';
import '../../domain/model/album.dart';
import '../../domain/model/geometry.dart';
import '../../domain/photos/replace_photo.dart';
import '../../domain/preflight/preflight.dart';
import '../../domain/spec/book_format.dart';
import '../book/book_page_view.dart';
import '../editor/editor_controller.dart';
import 'enhance_sheet.dart';

String issueMessage(AppLocalizations l, PreflightIssue i, Album album) {
  final f = BookFormat.byId(album.formatId);
  return switch (i.rule) {
    PreflightRule.lowDpi =>
      i.severity == Severity.blocker
          ? l.checkLowDpiBlock((i.value ?? 0).round())
          : l.checkLowDpiWarn((i.value ?? 0).round()),
    PreflightRule.faceInGutter => l.checkFaceGutter,
    PreflightRule.textOutsideSafeArea => l.checkTextSafe,
    PreflightRule.textTooSmall => l.checkTextSmall,
    PreflightRule.textOverflow => l.checkTextOverflow,
    PreflightRule.emptyFrame => l.checkEmptyFrame,
    PreflightRule.emptyText => l.checkEmptyText,
    PreflightRule.pageCount => l.checkPageCount(
      f.minPages,
      f.maxPages,
      album.pages.length,
    ),
    PreflightRule.duplicatePhoto => l.checkDuplicate,
    PreflightRule.missingGlyphs => l.checkGlyphs(i.detail ?? ''),
    PreflightRule.coverTitleOverflow => l.checkCoverTitle,
    PreflightRule.thinLine => l.checkThinLine,
  };
}

String issueLocation(AppLocalizations l, PreflightIssue i) =>
    switch (i.pageIndex) {
      null => l.checkWholeBook,
      kCoverFront => l.editorCover,
      kCoverBack => l.checkBackCover,
      kCoverSpine => l.checkSpine,
      final p => l.editorPage(p + 1),
    };

/// The photo in a low-resolution frame, when "Enhance for print" applies.
PhotoRef? _lowDpiPhoto(Album album, PreflightIssue issue) {
  if (issue.rule != PreflightRule.lowDpi) return null;
  final page = switch (issue.pageIndex) {
    kCoverFront => album.cover.front,
    kCoverBack => album.cover.back,
    final int i when i >= 0 && i < album.pages.length => album.pages[i],
    _ => null,
  };
  final frame = page?.frames.where((f) => f.id == issue.elementId).firstOrNull;
  final photo = album.photos[frame?.photoId];
  // Once enhanced, a photo is not enhanced again.
  return photo == null || photo.id.endsWith('~enhanced') ? null : photo;
}

bool _enhanceable(Album album, PreflightIssue issue) =>
    _lowDpiPhoto(album, issue) != null;

Future<void> _enhance(
  BuildContext context,
  EditorController controller,
  Album album,
  PreflightIssue issue,
) async {
  final photo = _lowDpiPhoto(album, issue);
  if (photo == null) return;
  final enhanced = await showEnhanceSheet(context, photo);
  if (enhanced == null) return;
  controller.apply((ops, a) => replacePhoto(a, photo.id, enhanced));
}

/// Print check (section 8.7): issues by severity, each with the problem
/// area highlighted and a one-tap fix.
class CheckScreen extends ConsumerWidget {
  const CheckScreen({required this.albumId, super.key});

  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final state = ref.watch(editorControllerProvider(albumId)).value;
    final kit = ref.watch(domainKitProvider).value;
    if (state == null || kit == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final controller = ref.read(editorControllerProvider(albumId).notifier);
    final report = state.report;
    final album = state.album;
    final fixable = report.issues.where((i) => i.fix != null).length;

    if (report.printReady) {
      unawaited(
        ref.read(analyticsProvider).track(AnalyticsEvent.preflightPassed, {
          'pages': album.pages.length,
        }),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.checkTitle)),
      body: report.issues.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Space.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_outlined, size: 64, color: c.secondary),
                    const SizedBox(height: Space.md),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        l.checkReady,
                        style: t.displaySmall?.copyWith(color: c.secondary),
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      l.checkReadyBody,
                      style: t.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: Space.xxl),
              children: [
                if (fixable > 0)
                  Padding(
                    padding: const EdgeInsets.all(Space.md),
                    child: PrimaryButton(
                      label: l.checkFixAll,
                      icon: Icons.auto_fix_high_outlined,
                      onPressed: () =>
                          controller.apply((ops, a) => kit.fixer.fixAll(a)),
                    ),
                  ),
                if (report.count(Severity.blocker) == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.md),
                    child: Text(l.checkOrderAnyway, style: t.bodySmall),
                  ),
                for (final (severity, title, color) in [
                  (Severity.blocker, l.checkBlockers, c.error),
                  (Severity.warning, l.checkWarnings, c.warning),
                  (Severity.info, l.checkInfo, c.info),
                ])
                  if (report.issues.any((i) => i.severity == severity)) ...[
                    SectionHeader(title),
                    for (final issue in report.issues.where(
                      (i) => i.severity == severity,
                    ))
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.md,
                          vertical: Space.xxs,
                        ),
                        child: _IssueCard(
                          album: album,
                          issue: issue,
                          color: color,
                          onFix: issue.fix == null
                              ? null
                              : () => controller.apply(
                                  (ops, a) => kit.fixer.apply(a, issue),
                                ),
                          onShow: () => context.pop(issue.pageIndex),
                          onEnhance: _enhanceable(album, issue)
                              ? () =>
                                    _enhance(context, controller, album, issue)
                              : null,
                        ),
                      ),
                  ],
              ],
            ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({
    required this.album,
    required this.issue,
    required this.color,
    required this.onFix,
    required this.onShow,
    this.onEnhance,
  });

  final Album album;
  final PreflightIssue issue;
  final Color color;
  final VoidCallback? onFix;
  final VoidCallback onShow;

  /// "Enhance for print" for photos under 200 dpi.
  final VoidCallback? onEnhance;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final p = issue.pageIndex;
    final page = switch (p) {
      null => null,
      kCoverFront => album.cover.front,
      kCoverBack => album.cover.back,
      kCoverSpine => null,
      final i => i < album.pages.length ? album.pages[i] : null,
    };
    final icon = issue.severity == Severity.blocker
        ? Icons.error_outline_rounded
        : Icons.warning_amber_rounded;
    return MemoriaCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (page != null)
            SizedBox(
              width: 84,
              child: ExcludeSemantics(
                child: BookPageView(
                  album: album,
                  page: page,
                  foreground: issue.areaMm == null
                      ? null
                      : _Highlight(
                          issue.areaMm!,
                          BookFormat.byId(album.formatId),
                          color,
                        ),
                ),
              ),
            ),
          if (page != null) const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: Space.xxs),
                    Text(issueLocation(l, issue), style: t.labelMedium),
                  ],
                ),
                const SizedBox(height: Space.xxs),
                Text(issueMessage(l, issue, album), style: t.bodyMedium),
                const SizedBox(height: Space.xs),
                Wrap(
                  spacing: Space.xs,
                  children: [
                    if (onEnhance != null)
                      FilledButton.tonalIcon(
                        onPressed: onEnhance,
                        icon: const Icon(
                          Icons.auto_fix_high_outlined,
                          size: 18,
                        ),
                        label: Text(l.enhanceAction),
                      ),
                    if (onFix != null)
                      OutlinedButton(onPressed: onFix, child: Text(l.checkFix)),
                    if (p != null && p >= -1)
                      TextButton(onPressed: onShow, child: Text(l.checkShow)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Highlight extends CustomPainter {
  _Highlight(this.area, this.format, this.color);

  final RectMm area;
  final BookFormat format;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / format.trimWMm;
    final r = Rect.fromLTWH(
      area.x * s,
      area.y * s,
      area.w * s,
      area.h * s,
    ).intersect(Offset.zero & size);
    canvas.drawRect(r, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_Highlight old) => old.area != area;
}
