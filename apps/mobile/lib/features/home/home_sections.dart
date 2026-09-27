import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/albums/album_repository.dart';
import '../../design/design.dart';
import '../../domain/model/album.dart';
import '../../domain/spec/book_format.dart';
import '../../router/app_router.dart';
import '../book/book_3d.dart';
import '../occasion/book_kind.dart';
import '../occasion/occasion_hero.dart';

/// Section title with an optional trailing note ("Step 1 of 4").
class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle(this.title, {this.trailing, super.key});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.lg,
        Space.md,
        Space.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: t.titleLarge),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: t.labelMedium?.copyWith(color: c.textSecondary),
            ),
        ],
      ),
    );
  }
}

String statusLabel(AppLocalizations l, AlbumStatus s) => switch (s) {
  AlbumStatus.draft => l.statusDraft,
  AlbumStatus.ordered => l.statusOrdered,
  AlbumStatus.delivered => l.statusDelivered,
  AlbumStatus.archived => l.statusArchived,
};

Color statusColor(MemoriaColors c, AlbumStatus s) => switch (s) {
  AlbumStatus.draft => c.textSecondary,
  AlbumStatus.ordered => c.primary,
  AlbumStatus.delivered => c.success,
  AlbumStatus.archived => c.textSecondary,
};

/// 3 × 2 grid of occasion tiles in a fixed order; rows arrive one by one.
class OccasionGrid extends StatelessWidget {
  const OccasionGrid({required this.firstIndex, super.key});

  /// Entry-motion index of the first row.
  final int firstIndex;

  @override
  Widget build(BuildContext context) {
    const kinds = BookKind.values;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: Column(
        children: [
          for (var row = 0; row < 2; row++)
            EntryMotion(
              index: firstIndex + row,
              child: Padding(
                padding: EdgeInsets.only(bottom: row == 0 ? Space.sm : 0),
                child: Row(
                  children: [
                    for (var col = 0; col < 3; col++) ...[
                      if (col > 0) const SizedBox(width: Space.sm),
                      Expanded(child: OccasionTile(kind: kinds[row * 3 + col])),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class OccasionTile extends StatefulWidget {
  const OccasionTile({required this.kind, super.key});

  final BookKind kind;

  @override
  State<OccasionTile> createState() => _OccasionTileState();
}

class _OccasionTileState extends State<OccasionTile> {
  bool _down = false;

  void _open() {
    HapticFeedback.lightImpact();
    context.push(Routes.occasion(widget.kind.name));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final kind = widget.kind;
    return Semantics(
      button: true,
      label: '${kind.label(l)}. ${kind.hint(l)}',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: _open,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: const Duration(milliseconds: 120),
          child: SizedBox(
            height: 124,
            child: Stack(
              children: [
                Positioned.fill(
                  child: OccasionHeroBackground(kind: kind, isHeader: false),
                ),
                ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: kind.tone.background(context),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            kind.icon,
                            size: 20,
                            color: kind.tone.icon(context),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          kind.label(l),
                          style: t.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          kind.hint(l),
                          style: t.bodySmall?.copyWith(
                            color: c.textSecondary,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontal rail that snaps; the centred card is full size, the others
/// 94 %.
class SnapRail extends StatefulWidget {
  const SnapRail({
    required this.itemCount,
    required this.itemWidth,
    required this.height,
    required this.itemBuilder,
    super.key,
  });

  final int itemCount;
  final double itemWidth;
  final double height;
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  State<SnapRail> createState() => _SnapRailState();
}

class _SnapRailState extends State<SnapRail> {
  PageController? _pages;
  double _lastWidth = 0;

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = Motion.reduced(context);
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, box) {
          if (_pages == null || box.maxWidth != _lastWidth) {
            _lastWidth = box.maxWidth;
            final old = _pages;
            _pages = PageController(
              viewportFraction: ((widget.itemWidth + Space.md) / box.maxWidth)
                  .clamp(0.2, 1.0),
              initialPage: old?.hasClients ?? false ? old!.page!.round() : 0,
            );
            if (old != null) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => old.dispose(),
              );
            }
          }
          final pages = _pages!;
          return AnimatedBuilder(
            animation: pages,
            builder: (context, _) {
              final page = pages.hasClients && pages.position.haveDimensions
                  ? pages.page ?? 0
                  : pages.initialPage.toDouble();
              return PageView.builder(
                controller: pages,
                padEnds: false,
                clipBehavior: Clip.none,
                itemCount: widget.itemCount,
                itemBuilder: (context, i) {
                  final d = (i - page).abs().clamp(0.0, 1.0);
                  return Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? Space.md : Space.md / 2,
                      right: Space.md / 2,
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Transform.scale(
                        scale: reduce ? 1 : 1 - 0.06 * d,
                        child: SizedBox(
                          width: widget.itemWidth,
                          child: widget.itemBuilder(context, i),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// "Three ways to keep it": Classic Album (main), Living Memories, Cartoon.
class WaysRail extends StatelessWidget {
  const WaysRail({required this.onPick, super.key});

  final ValueChanged<Edition> onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final ways = [
      (
        Edition.album,
        l.editionAlbumName,
        l.homeWayAlbumBody,
        Icons.menu_book_rounded,
      ),
      (
        Edition.livingMemories,
        l.editionVideoName,
        l.homeWayVideoBody,
        Icons.movie_filter_outlined,
      ),
      (
        Edition.illustrated,
        l.homeWayCartoonName,
        l.homeWayCartoonBody,
        Icons.brush_outlined,
      ),
    ];
    return SnapRail(
      itemCount: ways.length,
      itemWidth: 220,
      height: 200,
      itemBuilder: (context, i) {
        final (edition, name, body, icon) = ways[i];
        final main = edition == Edition.album;
        return Semantics(
          button: true,
          label: '$name. $body',
          child: GestureDetector(
            onTap: () => onPick(edition),
            child: Container(
              height: 200,
              padding: const EdgeInsets.all(Space.md),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: Radii.cardAll,
                border: Border.all(
                  color: main ? c.primary : c.border,
                  width: main ? 1.6 : 1,
                ),
                boxShadow: Shadows.soft(c),
              ),
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: c.surfaceTint,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: c.primary),
                        ),
                        const Spacer(),
                        if (main)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: c.primary,
                              borderRadius: Radii.pillAll,
                            ),
                            child: Text(
                              l.homeWayMain.toUpperCase(),
                              style: t.labelSmall?.copyWith(
                                color: c.onPrimary,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(name, style: t.titleMedium),
                    const SizedBox(height: Space.xxs),
                    Text(
                      body,
                      style: t.bodySmall?.copyWith(color: c.textBody),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "Your books": 3D covers with spines and a status chip, or an empty card.
class BookShelf extends ConsumerWidget {
  const BookShelf({required this.books, super.key});

  final List<AlbumSummary> books;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = MemoriaColors.of(context);
    final t = Theme.of(context).textTheme;
    if (books.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        child: CustomPaint(
          painter: _DashedBorder(c.border, Radii.card),
          child: Container(
            height: 120,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(Space.lg),
            child: Row(
              children: [
                Icon(Icons.shelves, color: c.textSecondary),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    l.homeShelfEmpty,
                    style: t.bodyMedium?.copyWith(color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SnapRail(
      itemCount: books.length,
      itemWidth: 150,
      height: 250,
      itemBuilder: (context, i) => ShelfBook(summary: books[i]),
    );
  }
}

class ShelfBook extends ConsumerWidget {
  const ShelfBook({required this.summary, super.key});

  final AlbumSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = MemoriaColors.of(context);
    final t = Theme.of(context).textTheme;
    final album = ref.watch(albumByIdProvider(summary.id)).value;
    return Semantics(
      button: true,
      label: l.homeOpenBook(summary.title),
      child: GestureDetector(
        onTap: () => context.push(Routes.albumPreview(summary.id)),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 172,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: album == null
                      ? const SizedBox.shrink()
                      : Book3D(
                          album: album,
                          width: math.min(
                            118,
                            150 * BookFormat.byId(album.formatId).aspect,
                          ),
                          yaw: -0.32,
                          pitch: 0.06,
                        ),
                ),
              ),
              const SizedBox(height: Space.xs),
              Text(
                summary.title,
                style: t.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Space.xxs),
              StatusPill(
                label: statusLabel(l, summary.status),
                color: statusColor(c, summary.status),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 12) {
        canvas.drawPath(m.extractPath(d, math.min(d + 6, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
