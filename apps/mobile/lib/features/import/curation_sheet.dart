import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/services/services.dart';
import '../../design/design.dart';
import '../../domain/model/album.dart';
import '../create/creation_controller.dart';

Future<void> showCurationSheet(BuildContext context) => showMemoriaSheet<void>(
  context,
  expand: true,
  builder: (_) => const CurationSheet(),
);

/// "In your book" / "Set aside" review (section 8.4).
class CurationSheet extends ConsumerWidget {
  const CurationSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final state = ref.watch(creationControllerProvider);
    final included = state.included;
    final aside = state.setAside;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Text(
              l.curationTitle(included.length, state.photos.length),
              style: t.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: Space.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Text(
              l.curationHint,
              style: t.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
          TabBar(
            tabs: [
              Tab(text: l.curationTabIn(included.length)),
              Tab(text: l.curationTabOut(aside.length)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _Grid(photos: included),
                _Grid(photos: aside, showReason: true),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(Space.md),
              child: PrimaryButton(
                label: l.curationLooksGood,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Grid extends ConsumerWidget {
  const _Grid({required this.photos, this.showReason = false});

  final List<PhotoRef> photos;
  final bool showReason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = MemoriaColors.of(context);
    final images = ref.watch(photoImagesProvider);
    final notifier = ref.read(creationControllerProvider.notifier);
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (photos.isEmpty) {
      return EmptyState(title: l.curationSetAside(0));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(Space.xs),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: Space.xs,
        crossAxisSpacing: Space.xs,
      ),
      itemCount: photos.length,
      itemBuilder: (context, i) {
        final p = photos[i];
        final reason = switch (p.excludedReason) {
          ExclusionReason.burst => l.curationReasonBurst,
          ExclusionReason.duplicate => l.curationReasonDuplicate,
          ExclusionReason.blur => l.curationReasonBlur,
          ExclusionReason.user => l.curationReasonUser,
          null => null,
        };
        final label = [
          if (p.takenAt != null)
            l.photoSemantics(DateFormat.yMMMMd(locale).format(p.takenAt!)),
          ?p.placeName,
          if (p.faces.isNotEmpty) l.photoPeople(p.faces.length),
          if (p.userPinned) l.curationFavourite,
          ?reason,
        ].join(', ');
        return Semantics(
          label: label,
          button: true,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              notifier.toggleExcluded(p.id);
            },
            onLongPress: () {
              HapticFeedback.lightImpact();
              notifier.togglePinned(p.id);
            },
            child: ClipRRect(
              borderRadius: Radii.inputAll,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: c.surface,
                    child: Image(
                      image: images.provider(p, size: 256),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                  if (p.userPinned)
                    PositionedDirectional(
                      top: 6,
                      end: 6,
                      child: Icon(
                        Icons.favorite_rounded,
                        color: c.onPrimary,
                        shadows: const [Shadow(blurRadius: 6)],
                      ),
                    ),
                  if (showReason && reason != null)
                    PositionedDirectional(
                      start: 0,
                      end: 0,
                      bottom: 0,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        child: Text(
                          reason,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
