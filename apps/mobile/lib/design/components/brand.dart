import 'package:material_ui/material_ui.dart';

import '../../app_config.dart';
import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';

/// The wordmark: "memoria." in Unbounded, the dot in primary.
class Wordmark extends StatelessWidget {
  const Wordmark({this.size = 24, this.onDark = false, super.key});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final c = MemoriaColors.of(context);
    final style = TextStyle(
      fontFamily: Fonts.unbounded,
      fontWeight: FontWeight.w600,
      fontSize: size,
      height: 1,
      letterSpacing: -0.02 * size,
      color: onDark ? c.textOnDark : c.textPrimary,
    );
    return Semantics(
      label: AppConfig.brandName,
      header: true,
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            text: AppConfig.brandName.toLowerCase(),
            style: style,
            children: [
              TextSpan(
                text: '.',
                style: style.copyWith(
                  color: onDark ? c.primaryOnDark : c.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round 44 × 44 icon button on a surface (header actions).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = true,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = MemoriaColors.of(context);
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: filled ? c.surface : Colors.transparent,
          shape: CircleBorder(
            side: filled ? BorderSide(color: c.border) : BorderSide.none,
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 22, color: c.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section entry motion: fade in and rise 12 px, [index] × 60 ms late.
/// Reduced motion: a plain cross-fade.
class EntryMotion extends StatefulWidget {
  const EntryMotion({required this.index, required this.child, super.key});

  final int index;
  final Widget child;

  @override
  State<EntryMotion> createState() => _EntryMotionState();
}

class _EntryMotionState extends State<EntryMotion>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Motion.entry);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Motion.stagger * widget.index, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = Motion.reduced(context);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final v = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: v,
          child: reduce
              ? child
              : Transform.translate(
                  offset: Offset(0, 12 * (1 - v)),
                  child: child,
                ),
        );
      },
    );
  }
}

/// Large title at the top of a tab screen (Books, Orders, Settings).
class TabHeader extends StatelessWidget {
  const TabHeader(this.title, {this.action, super.key});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.md + 4,
          Space.md,
          Space.md,
          Space.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
