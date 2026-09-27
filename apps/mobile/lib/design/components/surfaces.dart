import 'package:material_ui/material_ui.dart';

import '../colors.dart';
import '../tokens.dart';

/// White card with a 1 px border; a soft blue shadow when [raised].
class MemoriaCard extends StatelessWidget {
  const MemoriaCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Space.md),
    this.raised = false,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool raised;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = MemoriaColors.of(context);
    final bg = color ?? c.surface;
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: Radii.cardAll,
        child: content,
      );
    }
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: Radii.cardAll,
          border: color == null ? Border.all(color: c.border) : null,
          boxShadow: raised ? Shadows.soft(c) : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: Radii.cardAll,
          clipBehavior: Clip.antiAlias,
          child: content,
        ),
      ),
    );
  }
}

/// Selectable pill chip: white with a border when idle, primary when selected.
class MemoriaChip extends StatelessWidget {
  const MemoriaChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = MemoriaColors.of(context);
    return ChoiceChip(
      label: Text(label),
      avatar: icon == null
          ? null
          : Icon(icon, size: 18, color: selected ? c.onPrimary : c.textPrimary),
      selected: selected,
      onSelected: onSelected,
      labelStyle: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: selected ? c.onPrimary : c.textPrimary),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

/// Small status pill (Draft, Ordered, Delivered, Print-ready).
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.color,
    this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: Radii.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Opens a bottom sheet in the house style (28 radius).
Future<T?> showMemoriaSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool expand = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final content = Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: builder(ctx),
      );
      if (!expand) return content;
      return FractionallySizedBox(heightFactor: 0.92, child: content);
    },
  );
}

/// Section header used across settings and editor panels.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = MemoriaColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Space.md,
        Space.lg,
        Space.md,
        Space.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: c.textPrimary),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
