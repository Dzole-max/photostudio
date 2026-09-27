import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/albums/album_repository.dart';
import '../../data/samples/sample_books.dart';
import '../../data/settings/settings.dart';
import '../../design/design.dart';
import '../../domain/model/album.dart';
import '../../domain/spec/book_format.dart';
import '../../router/app_router.dart';
import '../book/book_3d.dart';
import '../create/creation_controller.dart';
import 'occasion_labels.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static String greeting(AppLocalizations l, String? name, DateTime now) {
    if (name == null) return l.homeGreetingDefault;
    final h = now.hour;
    if (h >= 5 && h < 12) return l.homeGreetingMorning(name);
    if (h >= 12 && h < 18) return l.homeGreetingAfternoon(name);
    return l.homeGreetingEvening(name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final name = ref.watch(
      settingsControllerProvider.select((s) => s.displayName),
    );
    final samples = ref.watch(sampleBooksProvider);
    final albums = ref.watch(albumListProvider);
    // Covers on the shelf follow edits made elsewhere.
    ref.listen(albumListProvider, (_, _) => ref.invalidate(albumByIdProvider));
    final books = albums.value ?? const <AlbumSummary>[];
    final preparing = books.isEmpty && samples.isLoading;

    void create({Occasion? occasion}) {
      ref
          .read(creationControllerProvider.notifier)
          .startGallery(occasion: occasion);
      context.push(Routes.import);
    }

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.md,
                Space.md,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              l.homeGreetingDefault,
                              style: t.displayMedium,
                            ),
                          ),
                          if (name != null)
                            Text(
                              greeting(l, name, DateTime.now()),
                              style: t.bodyMedium?.copyWith(
                                color: c.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _AvatarButton(name: name),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: preparing
                  ? SizedBox(
                      height: _Shelf.height,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: Space.sm),
                            Text(l.homeLoadingBooks, style: t.bodySmall),
                          ],
                        ),
                      ),
                    )
                  : books.isEmpty
                  ? (albums.hasValue
                        ? EmptyState(
                            title: l.homeEmptyTitle,
                            body: l.homeEmptyBody,
                          )
                        : const SizedBox(height: _Shelf.height))
                  : _Shelf(books: books),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.md,
                Space.lg,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: PrimaryButton(
                  label: l.homeCreateTitle,
                  icon: Icons.add_rounded,
                  onPressed: create,
                ),
              ),
            ),
            SliverToBoxAdapter(child: SectionHeader(l.homeStartFromOccasion)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: [
                    for (final o in const [
                      Occasion.wedding,
                      Occasion.travel,
                      Occasion.baby,
                      Occasion.birthday,
                      Occasion.family,
                    ])
                      MemoriaChip(
                        label: occasionLabel(l, o),
                        icon: occasionIcon(o),
                        selected: false,
                        onSelected: (_) => create(occasion: o),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: SectionHeader(l.homeTrySample)),
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: Space.md),
              sliver: SliverToBoxAdapter(child: _SampleStarts()),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: Space.xxl + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final c = MemoriaColors.of(context);
    final initial = name?.trim().characters.firstOrNull?.toUpperCase();
    return Semantics(
      button: true,
      label: context.l10n.navSettings,
      child: InkResponse(
        onTap: () => context.go(Routes.settings),
        radius: 28,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.surfaceRaised,
            border: Border.all(color: c.divider),
          ),
          child: initial == null
              ? Icon(Icons.person_outline_rounded, color: c.textPrimary)
              : Text(initial, style: Theme.of(context).textTheme.titleMedium),
        ),
      ),
    );
  }
}

/// "Make one with our photos": runs the real flow on the bundled photos.
class _SampleStarts extends ConsumerWidget {
  const _SampleStarts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    Future<void> start(String set) async {
      unawaited(context.push(Routes.importProgress));
      await ref.read(creationControllerProvider.notifier).startSample(set);
    }

    Widget tile(String set, String title, IconData icon) => Expanded(
      child: MemoriaCard(
        onTap: () => start(set),
        semanticLabel: title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: MemoriaColors.of(context).accent),
            const SizedBox(height: Space.sm),
            Text(title, style: t.titleSmall),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: Space.xs,
            bottom: Space.sm,
          ),
          child: Text(l.homeSampleBody, style: t.bodyMedium),
        ),
        Row(
          children: [
            tile(
              'wedding',
              l.homeSampleWedding,
              Icons.favorite_outline_rounded,
            ),
            const SizedBox(width: Space.sm),
            tile('travel', l.homeSampleTravel, Icons.map_outlined),
          ],
        ),
      ],
    );
  }
}

/// A horizontal 3D shelf: the centred book turns toward the reader, its
/// neighbours show their spines, and all of them lean with the scroll.
class _Shelf extends ConsumerStatefulWidget {
  const _Shelf({required this.books});

  static const height = 330.0;

  final List<AlbumSummary> books;

  @override
  ConsumerState<_Shelf> createState() => _ShelfState();
}

class _ShelfState extends ConsumerState<_Shelf>
    with SingleTickerProviderStateMixin {
  final _pages = PageController(viewportFraction: 0.6);
  late final _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  String? _opening;

  @override
  void dispose() {
    _pages.dispose();
    _open.dispose();
    super.dispose();
  }

  double get _page => _pages.hasClients && _pages.position.haveDimensions
      ? _pages.page ?? 0
      : _pages.initialPage.toDouble();

  Future<void> _tap(int i) async {
    if ((_page - i).abs() > 0.3) {
      await _pages.animateToPage(
        i,
        duration: Motion.medium,
        curve: Motion.curve,
      );
      return;
    }
    final id = widget.books[i].id;
    unawaited(HapticFeedback.lightImpact());
    if (!Motion.reduced(context)) {
      setState(() => _opening = id);
      await _open.forward(from: 0);
    }
    if (!mounted) return;
    await context.push(Routes.albumPreview(id));
    if (!mounted) return;
    _open.value = 0;
    setState(() => _opening = null);
  }

  Future<void> _delete(AlbumSummary summary) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.homeDeleteBook),
        content: Text(l.homeDeleteBookConfirm(summary.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: MemoriaColors.of(ctx).error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(albumRepositoryProvider).delete(summary.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final reduce = Motion.reduced(context);
    return SizedBox(
      height: _Shelf.height,
      child: Stack(
        children: [
          // The shelf board the books stand on.
          Positioned(
            left: 0,
            right: 0,
            top: 236,
            height: 14,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    c.divider.withValues(alpha: 0.9),
                    c.divider.withValues(alpha: 0.35),
                    c.divider.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: Listenable.merge([_pages, _open]),
            builder: (context, _) {
              final page = _page;
              return PageView.builder(
                controller: _pages,
                itemCount: widget.books.length,
                clipBehavior: Clip.none,
                itemBuilder: (context, i) {
                  final summary = widget.books[i];
                  final album = ref.watch(albumByIdProvider(summary.id)).value;
                  final delta = (i - page).clamp(-1.5, 1.5);
                  // Centred: turned toward the reader. Parallax ±6°.
                  final lean = reduce
                      ? 0.0
                      : delta.clamp(-1.0, 1.0) * 6 * math.pi / 180;
                  final yaw = -0.3 - delta.abs() * 0.35 + lean;
                  final opening = _opening == summary.id;
                  final open = opening
                      ? Curves.easeInOut.transform(_open.value)
                      : 0.0;
                  return GestureDetector(
                    onTap: () => _tap(i),
                    onLongPress: album?.flags.sample ?? false
                        ? null
                        : () => _delete(summary),
                    child: Semantics(
                      button: true,
                      label: l.homeOpenBook(summary.title),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 250,
                            child: album == null
                                ? const SizedBox.shrink()
                                : Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Transform.scale(
                                      scale:
                                          1 - delta.abs() * 0.12 + open * 0.08,
                                      alignment: Alignment.bottomCenter,
                                      child: ExcludeSemantics(
                                        child: Book3D(
                                          album: album,
                                          width: _bookWidth(album),
                                          yaw: yaw * (1 - open) - 0.05 * open,
                                          pitch: 0.08,
                                          open: open,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: Space.sm),
                          AnimatedOpacity(
                            duration: Motion.short,
                            opacity: delta.abs() < 0.5 ? 1 : 0.35,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Space.xs,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    summary.title,
                                    style: t.titleSmall,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: Space.xxs),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (album?.flags.sample ?? false)
                                        StatusPill(
                                          label: l.homeSampleBadge,
                                          color: c.accent,
                                        )
                                      else
                                        _status(l, c, summary.status),
                                      if (album != null) ...[
                                        const SizedBox(width: Space.xs),
                                        Text(
                                          l.homeBookPages(album.pages.length),
                                          style: t.bodySmall,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  /// Portrait and square books stand 200 px tall; landscape ones fit the
  /// same width budget.
  double _bookWidth(Album album) {
    final aspect = BookFormat.byId(album.formatId).aspect;
    return math.min(200 * aspect, 190);
  }

  Widget _status(AppLocalizations l, MemoriaColors c, AlbumStatus s) {
    final (label, color) = switch (s) {
      AlbumStatus.draft => (l.statusDraft, c.textSecondary),
      AlbumStatus.ordered => (l.statusOrdered, c.secondary),
      AlbumStatus.archived => (l.statusArchived, c.textSecondary),
    };
    return StatusPill(label: label, color: color);
  }
}
