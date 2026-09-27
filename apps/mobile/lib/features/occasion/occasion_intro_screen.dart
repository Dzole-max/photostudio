import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../design/design.dart';
import '../home/home_screen.dart';
import 'book_kind.dart';
import 'occasion_hero.dart';

/// Opened from an occasion tile: what the book holds and how making it goes,
/// then straight into the photo picker with the occasion pre-selected.
class OccasionIntroScreen extends ConsumerWidget {
  const OccasionIntroScreen({required this.kind, super.key});

  final BookKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final steps = [
      (l.occasionStep1, l.occasionStep1Hint),
      (l.occasionStep2, l.occasionStep2Hint),
      (l.occasionStep3, l.occasionStep3Hint),
      (l.occasionStep4, l.occasionStep4Hint),
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(
                    height: 330,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: OccasionHeroBackground(
                            kind: kind,
                            isHeader: true,
                          ),
                        ),
                        SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              Space.md,
                              Space.xs,
                              Space.lg,
                              Space.lg,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RoundIconButton(
                                  icon: Icons.arrow_back_rounded,
                                  label: MaterialLocalizations.of(context)
                                      .backButtonTooltip,
                                  onPressed: () => context.pop(),
                                ),
                                const Spacer(),
                                EntryMotion(
                                  index: 2,
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: c.surface.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Icon(
                                      kind.icon,
                                      size: 34,
                                      color: kind.tone.icon(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: Space.md),
                                EntryMotion(
                                  index: 3,
                                  child: Semantics(
                                    header: true,
                                    child: Text(
                                      kind.title(l),
                                      style: t.displaySmall,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: Space.xs),
                                EntryMotion(
                                  index: 4,
                                  child: Text(
                                    kind.about(l),
                                    style: t.bodyMedium?.copyWith(
                                      color: c.textBody,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  EntryMotion(
                    index: 5,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.lg,
                        Space.lg,
                        Space.lg,
                        Space.sm,
                      ),
                      child: Text(
                        l.occasionHowItGoes.toUpperCase(),
                        style: t.labelSmall?.copyWith(letterSpacing: 1.4),
                      ),
                    ),
                  ),
                  for (var i = 0; i < steps.length; i++)
                    EntryMotion(
                      index: 6 + i,
                      child: _StepRow(
                        number: i + 1,
                        title: steps[i].$1,
                        hint: steps[i].$2,
                        current: i == 0,
                      ),
                    ),
                  const SizedBox(height: Space.lg),
                ],
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(
                Space.md,
                Space.xs,
                Space.md,
                Space.md,
              ),
              child: PrimaryButton(
                label: kind.action(l),
                icon: Icons.add_photo_alternate_outlined,
                onPressed: () =>
                    startCreate(context, ref, occasion: kind.occasion),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.title,
    required this.hint,
    required this.current,
  });

  final int number;
  final String title;
  final String hint;

  /// The step you are about to do, highlighted in primary.
  final bool current;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.xxs,
      ),
      child: Container(
        padding: const EdgeInsets.all(Space.sm),
        decoration: BoxDecoration(
          color: current ? c.surfaceTint : c.surface,
          borderRadius: Radii.cardAll,
          border: Border.all(color: current ? c.primary : c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: current ? c.primary : c.surfaceTint,
              ),
              child: Text(
                '$number',
                style: t.titleSmall?.copyWith(
                  color: current ? c.onPrimary : c.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.titleSmall?.copyWith(
                      color: current ? c.primary : c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(hint, style: t.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
