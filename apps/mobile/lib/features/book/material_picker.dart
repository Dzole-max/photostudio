import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../design/design.dart';
import '../../domain/model/album.dart';
import '../../domain/pricing/pricing.dart';
import '../editor/panels/format_panel.dart' show money;
import 'book_3d.dart';

String finishName(AppLocalizations l, CoverFinish f) => switch (f) {
  CoverFinish.matte => l.finishMatte,
  CoverFinish.gloss => l.finishGloss,
  CoverFinish.linen => l.finishLinen,
  CoverFinish.leather => l.finishLeather,
};

/// Cover material in 3D: the book turns slowly (or with a drag) and is
/// re-rendered in the chosen material; each option shows its surcharge.
class MaterialPicker extends StatefulWidget {
  const MaterialPicker({
    required this.album,
    required this.catalog,
    required this.onChanged,
    super.key,
  });

  final Album album;
  final Catalog catalog;
  final ValueChanged<CoverFinish> onChanged;

  @override
  State<MaterialPicker> createState() => _MaterialPickerState();
}

class _MaterialPickerState extends State<MaterialPicker>
    with SingleTickerProviderStateMixin {
  late final _turn = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !Motion.reduced(context)) _turn.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final product = widget.catalog.product(widget.album.formatId);
    final selected = widget.album.coverFinish;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onHorizontalDragUpdate: (d) => setState(
            () => _drag = (_drag + d.delta.dx / 200).clamp(-0.6, 0.6),
          ),
          child: SizedBox(
            height: 200,
            child: Center(
              child: AnimatedBuilder(
                animation: _turn,
                builder: (context, _) {
                  final yaw =
                      -0.2 -
                      0.3 * Curves.easeInOut.transform(_turn.value) +
                      _drag;
                  return Book3D(
                    album: widget.album,
                    width: 150,
                    yaw: yaw,
                    pitch: 0.12,
                    finish: selected,
                    semanticLabel: finishName(l, selected),
                  );
                },
              ),
            ),
          ),
        ),
        Text(
          l.finishDragHint,
          textAlign: TextAlign.center,
          style: t.bodySmall?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [
            for (final f in CoverFinish.values)
              Builder(
                builder: (context) {
                  final available = product.finishes.contains(f);
                  final cents = product.finishSurchargeCents[f] ?? 0;
                  final extra = cents == 0
                      ? l.finishIncluded
                      : '+${money(cents, widget.catalog.currency, locale)}';
                  return Opacity(
                    opacity: available ? 1 : 0.45,
                    child: ChoiceChip(
                      label: Text(
                        available
                            ? '${finishName(l, f)} · $extra'
                            : finishName(l, f),
                      ),
                      selected: f == selected,
                      onSelected: available
                          ? (_) {
                              HapticFeedback.selectionClick();
                              widget.onChanged(f);
                            }
                          : null,
                    ),
                  );
                },
              ),
          ],
        ),
        if (!product.finishes.contains(CoverFinish.linen)) ...[
          const SizedBox(height: Space.xs),
          Text(
            l.finishNeedsHardcover,
            style: t.bodySmall?.copyWith(color: c.textSecondary),
          ),
        ],
      ],
    );
  }
}
