import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../data/domain_kit.dart';
import '../../data/services/services.dart';
import '../../design/design.dart';
import '../../domain/illustration/stylize.dart';
import '../../domain/model/album.dart';
import '../../router/app_router.dart';
import '../book/book_page_view.dart';
import 'cover_preview.dart';
import 'creation_controller.dart';

String editionName(AppLocalizations l, Edition e) => switch (e) {
  Edition.album => l.editionAlbumName,
  Edition.livingMemories => l.editionVideoName,
  Edition.illustrated => l.editionCartoonName,
};

String editionBody(AppLocalizations l, Edition e) => switch (e) {
  Edition.album => l.editionAlbumBody,
  Edition.livingMemories => l.editionVideoBody,
  Edition.illustrated => l.editionCartoonBody,
};

IconData editionIcon(Edition e) => switch (e) {
  Edition.album => Icons.menu_book_outlined,
  Edition.livingMemories => Icons.movie_filter_outlined,
  Edition.illustrated => Icons.brush_outlined,
};

/// Editions enabled by feature flags (the album is always available).
List<Edition> availableEditions(WidgetRef ref) {
  final config = ref.watch(appConfigProvider);
  return [
    Edition.album,
    if (config.featureLivingMemories) Edition.livingMemories,
    if (config.featureIllustrated) Edition.illustrated,
  ];
}

/// "Choose your edition" (after curation, before the occasion card): the
/// three products, each previewed with the user's own photos.
class EditionScreen extends ConsumerWidget {
  const EditionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final state = ref.watch(creationControllerProvider);
    final editions = availableEditions(ref);
    final chosen = state.edition;
    final photos = [...state.included]
      ..sort((a, b) => b.quality.overall.compareTo(a.quality.overall));

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Semantics(
                header: true,
                child: Text(l.editionTitle, style: t.displaySmall),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.xs,
                Space.lg,
                Space.sm,
              ),
              child: Text(l.editionIntro, style: t.bodyMedium),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.md,
                  vertical: Space.xs,
                ),
                children: [
                  for (final e in editions) ...[
                    _EditionCard(
                      edition: e,
                      selected: e == chosen,
                      onTap: () => ref
                          .read(creationControllerProvider.notifier)
                          .setEdition(e),
                      preview: switch (e) {
                        Edition.album => const _AlbumPreview(),
                        Edition.livingMemories => _MemoriesPreview(
                          photos: photos.take(3).toList(),
                        ),
                        Edition.illustrated => _CartoonPreview(
                          photo:
                              photos
                                  .where((p) => p.faces.isNotEmpty)
                                  .firstOrNull ??
                              photos.firstOrNull,
                        ),
                      },
                    ),
                    const SizedBox(height: Space.sm),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.xs,
                Space.lg,
                Space.md,
              ),
              child: PrimaryButton(
                label: l.editionContinue(editionName(l, chosen)),
                onPressed: () => context.push(Routes.createOccasion),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditionCard extends StatelessWidget {
  const _EditionCard({
    required this.edition,
    required this.selected,
    required this.onTap,
    required this.preview,
  });

  final Edition edition;
  final bool selected;
  final VoidCallback onTap;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '${editionName(l, edition)}. ${editionBody(l, edition)}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.short,
          curve: Motion.curve,
          decoration: BoxDecoration(
            color: selected ? c.surfaceRaised : c.surface,
            borderRadius: Radii.cardAll,
            border: Border.all(
              color: selected ? c.primary : Colors.transparent,
              width: 2,
            ),
            boxShadow: selected ? Shadows.raised(c) : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 140, child: preview),
                Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Row(
                    children: [
                      Icon(
                        editionIcon(edition),
                        color: selected ? c.primary : c.textSecondary,
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    editionName(l, edition),
                                    style: t.titleMedium,
                                  ),
                                ),
                                if (edition == Edition.album) ...[
                                  const SizedBox(width: Space.xs),
                                  StatusPill(
                                    label: l.editionMostLoved,
                                    color: c.accent,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(editionBody(l, edition), style: t.bodySmall),
                          ],
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected ? c.primary : c.textSecondary,
                      ),
                    ],
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

/// A looping, slowly opening book with the auto cover.
class _AlbumPreview extends ConsumerStatefulWidget {
  const _AlbumPreview();

  @override
  ConsumerState<_AlbumPreview> createState() => _AlbumPreviewState();
}

class _AlbumPreviewState extends ConsumerState<_AlbumPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(creationControllerProvider);
    final kit = ref.watch(domainKitProvider).value;
    final colors = MemoriaColors.of(context);
    if (kit == null || state.occasion == null) {
      return ColoredBox(color: colors.surface);
    }
    final lang = Localizations.localeOf(context).languageCode;
    final album = previewAlbum(
      state,
      kit,
      state.themeId ?? 'minimal_gallery',
      lang,
    );
    final heroId = album.cover.slots.heroPhotoId;
    final hero = heroId == null ? null : album.photos[heroId];
    final images = ref.watch(photoImagesProvider);
    return ColoredBox(
      color: const Color(0xFFE9E1D3),
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = _c.value;
            double open;
            if (v < 0.15) {
              open = 0;
            } else if (v < 0.5) {
              open = Curves.easeInOutCubic.transform((v - 0.15) / 0.35);
            } else if (v < 0.8) {
              open = 1;
            } else {
              open = 1 - Curves.easeInOutCubic.transform((v - 0.8) / 0.2);
            }
            const w = 104.0;
            final h = w / (album.formatId == 'landscape_28' ? 1.375 : 1.0);
            return Transform.translate(
              offset: Offset(-w / 2 * (1 - open), 0),
              child: SizedBox(
                width: w * 2,
                height: h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Right page: first photo on paper.
                    Positioned(
                      left: w,
                      width: w,
                      top: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBF8F2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 12,
                              offset: const Offset(2, 6),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: hero == null
                              ? null
                              : Image(
                                  image: images.provider(hero, size: 256),
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                    // Cover swinging open around the spine.
                    Positioned(
                      left: w,
                      width: w,
                      top: 0,
                      bottom: 0,
                      child: Transform(
                        alignment: Alignment.centerLeft,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0018)
                          ..rotateY(-open * math.pi * 0.92),
                        child: open > 0.5
                            ? const ColoredBox(color: Color(0xFFF4EFE6))
                            : BookPageView(
                                album: album,
                                page: album.cover.front,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Three of the user's photos drifting at different depths.
class _MemoriesPreview extends ConsumerStatefulWidget {
  const _MemoriesPreview({required this.photos});

  final List<PhotoRef> photos;

  @override
  ConsumerState<_MemoriesPreview> createState() => _MemoriesPreviewState();
}

class _MemoriesPreviewState extends ConsumerState<_MemoriesPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.value = 0.3;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = ref.watch(photoImagesProvider);
    final photos = widget.photos;
    return ColoredBox(
      color: const Color(0xFF15130F),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * 2 * math.pi;
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < photos.length; i++)
                Transform.translate(
                  offset: Offset(
                    math.sin(t + i * 2.1) * (14.0 + i * 10),
                    math.cos(t * 0.7 + i) * 6,
                  ),
                  child: Transform.rotate(
                    angle: (i - 1) * 0.08 + math.sin(t + i) * 0.02,
                    child: Transform.scale(
                      scale: 1.0 + i * 0.08 + math.sin(t * 0.5 + i) * 0.03,
                      child: Container(
                        width: 110,
                        height: 120,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: Image(
                          image: images.provider(photos[i], size: 256),
                          fit: BoxFit.cover,
                          alignment: Alignment(math.sin(t + i) * 0.6, 0),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 12,
                bottom: 10,
                child: Icon(
                  Icons.play_circle_outline_rounded,
                  color: Colors.white.withValues(alpha: 0.85),
                  size: 30,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Uint8List _stylizePreview((Uint8List, int) args) => stylizeEncoded(
  args.$1,
  IllustrationStyle.values[args.$2],
  workSide: 520,
  longSide: 520,
);

/// Before/after wipe of one photo into the illustrated style.
class _CartoonPreview extends ConsumerStatefulWidget {
  const _CartoonPreview({required this.photo});

  final PhotoRef? photo;

  @override
  ConsumerState<_CartoonPreview> createState() => _CartoonPreviewState();
}

class _CartoonPreviewState extends ConsumerState<_CartoonPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );
  Uint8List? _illustrated;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = widget.photo;
    final asset = p?.localAssetId;
    if (asset == null) return;
    final bytes = await ref
        .read(photoImagesProvider)
        .libraryFor(asset)
        .thumbnailBytes(asset, 512);
    if (bytes == null) return;
    final out = await compute(_stylizePreview, (
      bytes,
      IllustrationStyle.comic.index,
    ));
    if (mounted) setState(() => _illustrated = out);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final p = widget.photo;
    final colors = MemoriaColors.of(context);
    if (p == null) return ColoredBox(color: colors.surface);
    final images = ref.watch(photoImagesProvider);
    final after = _illustrated;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final split = 0.12 + Curves.easeInOutSine.transform(_c.value) * 0.76;
        return LayoutBuilder(
          builder: (context, box) => Stack(
            fit: StackFit.expand,
            children: [
              Image(
                image: images.provider(p, size: 512),
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.5),
              ),
              if (after != null)
                ClipRect(
                  clipper: _RightOf(split),
                  child: Image.memory(
                    after,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    alignment: const Alignment(0, -0.5),
                  ),
                ),
              Positioned(
                left: box.maxWidth * split - 1,
                top: 0,
                bottom: 0,
                width: 2,
                child: const ColoredBox(color: Colors.white),
              ),
              Positioned(left: 10, top: 8, child: _Tag(l.editionBefore, t)),
              Positioned(right: 10, top: 8, child: _Tag(l.editionAfter, t)),
              if (after == null)
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        );
      },
    );
  }
}

class _RightOf extends CustomClipper<Rect> {
  _RightOf(this.split);

  final double split;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(size.width * split, 0, size.width, size.height);

  @override
  bool shouldReclip(_RightOf old) => old.split != split;
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.t);

  final String text;
  final TextTheme t;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: Radii.pillAll,
    ),
    child: Text(text, style: t.labelSmall?.copyWith(color: Colors.white)),
  );
}
