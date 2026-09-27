import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/services/services.dart';
import '../../design/design.dart';
import '../../router/app_router.dart';
import '../create/creation_controller.dart';
import 'curation_sheet.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final state = ref.watch(creationControllerProvider);
    final progress = state.progress;
    final done = progress?.result != null;
    final images = ref.watch(photoImagesProvider);
    final library = state.library;

    if (state.error != null && !done) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorState(
          title: l.errorGenericTitle,
          body: l.errorGenericBody,
          retryLabel: l.commonRetry,
          onRetry: () =>
              ref.read(creationControllerProvider.notifier).analyse(),
        ),
      );
    }

    final total = progress?.total ?? state.selection.length;
    final count = progress?.done ?? 0;
    final latest = progress?.latest ?? const <String>[];

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Thumbnails flowing in.
              SizedBox(
                height: 96,
                child: ExcludeSemantics(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      for (var i = 0; i < latest.length; i++)
                        AnimatedPositioned(
                          key: ValueKey(latest[i]),
                          duration: Motion.long,
                          curve: Motion.curve,
                          left:
                              (MediaQuery.sizeOf(context).width -
                                      2 * Space.lg) /
                                  2 -
                              36 +
                              // The fan is centred as it grows.
                              (i - (latest.length - 1) / 2) * 26.0,
                          top: 12 + (i.isEven ? 0 : 6),
                          child: AnimatedOpacity(
                            duration: Motion.long,
                            opacity: 1 - (latest.length - 1 - i) * 0.07,
                            child: Transform.rotate(
                              angle: (i % 3 - 1) * 0.05,
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: c.surfaceRaised,
                                  borderRadius: Radii.paperAll,
                                  boxShadow: Shadows.soft(c),
                                ),
                                padding: const EdgeInsets.all(3),
                                child: library == null
                                    ? null
                                    : Image(
                                        image: images
                                            .libraryFor(latest[i])
                                            .imageProvider(
                                              latest[i],
                                              size: 160,
                                            ),
                                        fit: BoxFit.cover,
                                        gaplessPlayback: true,
                                      ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.xl),
              if (!done) ...[
                Text(
                  count >= total && total > 0
                      ? l.progressCurating
                      : l.progressReading(count, total),
                  style: t.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.md),
                CalmProgress(value: total == 0 ? null : count / total),
                const SizedBox(height: Space.sm),
                Text(
                  l.progressBody,
                  style: t.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(
                  l.curationTitle(state.included.length, state.photos.length),
                  style: t.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.sm),
                Text(
                  l.curationSetAside(state.setAside.length),
                  style: t.bodyMedium?.copyWith(color: c.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.md),
                Center(
                  child: SecondaryButton(
                    label: l.progressReviewPhotos,
                    icon: Icons.grid_view_rounded,
                    expand: false,
                    onPressed: () => showCurationSheet(context),
                  ),
                ),
              ],
              const Spacer(),
              if (done)
                PrimaryButton(
                  label: l.commonContinue,
                  onPressed: state.included.length >= kMinPhotosForBook
                      ? () => context.push(Routes.createEdition)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
