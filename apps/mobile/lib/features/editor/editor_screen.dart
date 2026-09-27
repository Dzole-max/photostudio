import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/settings/settings.dart';
import '../../design/design.dart';
import '../../domain/model/album.dart';
import '../../domain/preflight/preflight.dart';
import '../../domain/spec/book_format.dart';
import '../../router/app_router.dart';
import '../create/edition_screen.dart';
import 'editable_page.dart';
import 'editions_sheet.dart';
import 'editor_controller.dart';
import 'panels/editor_panels.dart';
import 'photo_bar.dart';
import 'template_strip.dart';
import 'text_editor_sheet.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({required this.albumId, super.key});

  final String albumId;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final _pager = PageController();
  bool? _guides;
  int _spread = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  bool get _showGuides =>
      _guides ?? !ref.read(settingsControllerProvider).printGuidesSeen;

  void _toggleGuides() {
    setState(() => _guides = !_showGuides);
    unawaited(
      ref.read(settingsControllerProvider.notifier).markPrintGuidesSeen(),
    );
  }

  Future<void> _editTitle(Album album) async {
    final l = context.l10n;
    final controller = TextEditingController(text: album.title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.editorBookTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty || result == album.title) return;
    ref
        .read(editorControllerProvider(widget.albumId).notifier)
        .apply((ops, a) => ops.setTitle(a, result));
  }

  void _goToPage(int pageIndex) {
    final spread = pageIndex < 0 ? 0 : spreadOfPage(pageIndex) + 1;
    _pager.animateToPage(spread, duration: Motion.medium, curve: Motion.curve);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final async = ref.watch(editorControllerProvider(widget.albumId));
    final controller = ref.read(
      editorControllerProvider(widget.albumId).notifier,
    );

    ref.listen(
      editorControllerProvider(widget.albumId)
          .select((s) => s.value?.selection),
      (prev, next) {
        if (next is EditorTextSelection && prev != next) {
          unawaited(
            showTextEditorSheet(
              context,
              widget.albumId,
              next,
            ).then((_) => controller.select(null)),
          );
        }
      },
    );

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(
          title: l.errorGenericTitle,
          body: l.errorGenericBody,
          retryLabel: l.commonRetry,
          onRetry: () =>
              ref.invalidate(editorControllerProvider(widget.albumId)),
        ),
      ),
      data: (state) {
        final album = state.album;
        final spreads = spreadsOf(album.pages.length);
        final issues = state.issueCount;
        final blockers = state.report.count(Severity.blocker);
        final selection = state.selection;

        Widget bottom;
        if (state.swapFrom != null) {
          bottom = _Hint(
            text: l.photoSwapHint,
            onCancel: () => controller.select(null),
          );
        } else if (selection is FrameSelection) {
          bottom = PhotoBar(albumId: widget.albumId, selection: selection);
        } else if (selection is PageSelection) {
          bottom = TemplateStrip(
            albumId: widget.albumId,
            pageIndex: selection.pageIndex,
          );
        } else {
          bottom = EditorPanels(
            albumId: widget.albumId,
            currentSpread: _spread,
            onGoToPage: _goToPage,
          );
        }

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            // Reached with go() after designing: nothing to pop, go home.
            leading: context.canPop()
                ? null
                : IconButton(
                    tooltip: l.navHome,
                    icon: const Icon(Icons.home_outlined),
                    onPressed: () => context.go(Routes.home),
                  ),
            title: Semantics(
              button: true,
              label: '${l.editorBookTitle}: ${album.title}',
              child: GestureDetector(
                onTap: () => _editTitle(album),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        album.title,
                        style: t.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (availableEditions(ref).length > 1)
                LabeledIconButton(
                  icon: Icons.auto_awesome_outlined,
                  label: l.editionsButton,
                  onPressed: () => showEditionsSheet(context, widget.albumId),
                ),
              LabeledIconButton(
                icon: Icons.undo_rounded,
                label: l.editorUndo,
                onPressed: state.canUndo ? controller.undo : null,
              ),
              LabeledIconButton(
                icon: Icons.redo_rounded,
                label: l.editorRedo,
                onPressed: state.canRedo ? controller.redo : null,
              ),
              Semantics(
                label: '${l.editorPreview}, ${l.editorIssues(issues)}',
                button: true,
                child: Badge(
                  isLabelVisible: issues > 0,
                  label: Text('$issues'),
                  backgroundColor: blockers > 0 ? c.error : c.warning,
                  child: TextButton(
                    onPressed: () async {
                      await controller.flush();
                      if (context.mounted) {
                        unawaited(
                          context.push(Routes.albumPreview(widget.albumId)),
                        );
                      }
                    },
                    child: Text(l.editorPreview),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: l.commonMore,
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (v) {
                  switch (v) {
                    case 'check':
                      context.push(Routes.albumCheck(widget.albumId));
                    case 'guides':
                      _toggleGuides();
                    case 'dedication':
                      context.push(Routes.albumDedication(widget.albumId));
                    case 'shuffle':
                      controller.apply((ops, a) => ops.shuffle(a));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.editorShuffleDone)),
                      );
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'check',
                    child: Text(l.editorPrintCheck),
                  ),
                  CheckedPopupMenuItem(
                    value: 'guides',
                    checked: _showGuides,
                    child: Text(l.editorPrintGuides),
                  ),
                  PopupMenuItem(value: 'shuffle', child: Text(l.editorShuffle)),
                  PopupMenuItem(
                    value: 'dedication',
                    child: Text(l.dedicationMenu),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              if (album.flags.blankPagesAdded > 0)
                MaterialBanner(
                  content: Text(
                    l.editorBlankNotice(album.flags.blankPagesAdded),
                    style: t.bodySmall,
                  ),
                  backgroundColor: c.surface,
                  actions: const [SizedBox.shrink()],
                ),
              if (_showGuides)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.md,
                    vertical: Space.xxs,
                  ),
                  child: Text(
                    l.editorGuidesLegend,
                    style: t.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(
                child: PageView.builder(
                  controller: _pager,
                  itemCount: spreads.length + 1,
                  onPageChanged: (i) => setState(() => _spread = i),
                  itemBuilder: (context, i) {
                    final guides = _showGuides;
                    if (i == 0) {
                      return _SpreadFrame(
                        label: l.editorCover,
                        child: FractionallySizedBox(
                          widthFactor: 0.6,
                          child: EditablePage(
                            albumId: widget.albumId,
                            album: album,
                            pageIndex: -1,
                            guides: guides,
                            selection: selection,
                          ),
                        ),
                      );
                    }
                    final (left, right) = spreads[i - 1];
                    final label = left == null
                        ? l.editorPage(right! + 1)
                        : (right == null
                              ? l.editorPage(left + 1)
                              : l.editorPages(left + 1, right + 1));
                    return _SpreadFrame(
                      label: label,
                      child: _Spread(
                        albumId: widget.albumId,
                        album: album,
                        left: left,
                        right: right,
                        guides: guides,
                        selection: selection,
                        swapping: state.swapFrom != null,
                      ),
                    );
                  },
                ),
              ),
              AnimatedSwitcher(duration: Motion.short, child: bottom),
            ],
          ),
        );
      },
    );
  }
}

class _SpreadFrame extends StatelessWidget {
  const _SpreadFrame({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: InteractiveViewer(
            maxScale: 4,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(Space.md),
                child: child,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: Space.xs),
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
      ],
    );
  }
}

/// Two facing pages with the gutter shadow, like an open book.
class _Spread extends StatelessWidget {
  const _Spread({
    required this.albumId,
    required this.album,
    required this.left,
    required this.right,
    required this.guides,
    required this.selection,
    required this.swapping,
  });

  final String albumId;
  final Album album;
  final int? left;
  final int? right;
  final bool guides;
  final EditorSelection? selection;
  final bool swapping;

  @override
  Widget build(BuildContext context) {
    final c = MemoriaColors.of(context);
    final f = BookFormat.byId(album.formatId);
    final pageAspect =
        (f.trimWMm + (guides ? 8 : 0)) / (f.trimHMm + (guides ? 8 : 0));
    Widget side(int? index) => Expanded(
      child: index == null
          ? const SizedBox.shrink()
          : EditablePage(
              albumId: albumId,
              album: album,
              pageIndex: index,
              guides: guides,
              selection: selection,
              swapping: swapping,
            ),
    );
    return AspectRatio(
      aspectRatio: pageAspect * 2 + (guides ? 0.04 : 0),
      child: DecoratedBox(
        decoration: BoxDecoration(boxShadow: Shadows.raised(c)),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                side(left),
                if (guides) const SizedBox(width: 6),
                side(right),
              ],
            ),
            // Gutter shadow.
            if (left != null && right != null && !guides)
              Align(
                child: IgnorePointer(
                  child: FractionallySizedBox(
                    widthFactor: 0.06,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0),
                            Colors.black.withValues(alpha: 0.10),
                            Colors.black.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text, required this.onCancel});

  final String text;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: MemoriaCard(
          child: Row(
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                color: MemoriaColors.of(context).info,
              ),
              const SizedBox(width: Space.sm),
              Expanded(child: Text(text)),
              TextButton(onPressed: onCancel, child: Text(l.commonCancel)),
            ],
          ),
        ),
      ),
    );
  }
}
