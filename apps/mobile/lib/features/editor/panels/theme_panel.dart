import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n.dart';
import '../../../design/design.dart';
import '../../../domain/theme/book_theme.dart';
import '../../../domain/theme/color_math.dart';
import '../../book/book_painter.dart';
import '../../create/occasion_screen.dart';
import '../editor_controller.dart';

/// The ten book themes plus a gentle accent-colour tweak.
class ThemePanel extends ConsumerWidget {
  const ThemePanel({required this.albumId, super.key});

  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final state = ref.watch(editorControllerProvider(albumId)).value;
    if (state == null) return const SizedBox.shrink();
    final album = state.album;
    final controller = ref.read(editorControllerProvider(albumId).notifier);
    final theme = BookTheme.byId(album.themeId);
    final base = Rgb.hex(theme.accent).toHsl();
    final accents = [
      theme.accent,
      for (final d in [-30.0, -15.0, 15.0, 30.0])
        base.withHue(base.h + d).toRgb().hex,
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      children: [
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            itemCount: kBookThemes.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
            itemBuilder: (context, i) {
              final th = kBookThemes[i];
              final selected = th.id == album.themeId;
              return Semantics(
                button: true,
                selected: selected,
                label: themeName(l, th.id),
                child: GestureDetector(
                  onTap: selected
                      ? null
                      : () => controller.apply(
                          (ops, a) => ops.changeTheme(a, th.id),
                        ),
                  child: SizedBox(
                    width: 92,
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: Motion.short,
                          height: 76,
                          decoration: BoxDecoration(
                            color: hexColor(th.background),
                            borderRadius: Radii.inputAll,
                            border: Border.all(
                              color: selected ? c.primary : c.divider,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(Space.xs),
                          child: ExcludeSemantics(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Aa',
                                  style: TextStyle(
                                    fontFamily: th.displayFont,
                                    fontWeight: fontWeightOf(th.displayWeight),
                                    fontSize: 20,
                                    color: hexColor(th.text),
                                  ),
                                ),
                                const Spacer(),
                                Row(
                                  children: [
                                    for (final col in [th.accent, th.text])
                                      Container(
                                        width: 14,
                                        height: 14,
                                        margin: const EdgeInsets.only(right: 4),
                                        decoration: BoxDecoration(
                                          color: hexColor(col),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ExcludeSemantics(
                          child: Text(
                            themeName(l, th.id),
                            style: t.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: Space.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          child: Row(
            children: [
              Text(l.themeAccent, style: t.labelMedium),
              const Spacer(),
              for (final a in accents)
                Semantics(
                  button: true,
                  selected: a == album.accentColor,
                  label: a == theme.accent
                      ? l.themeAccentReset
                      : '${l.themeAccent} $a',
                  child: GestureDetector(
                    onTap: () =>
                        controller.apply((ops, al) => ops.setAccent(al, a)),
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        color: hexColor(a),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: a == album.accentColor
                              ? c.textPrimary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
