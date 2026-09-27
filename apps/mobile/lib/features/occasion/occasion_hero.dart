import 'package:material_ui/material_ui.dart';

import '../../design/design.dart';
import 'book_kind.dart';

String occasionHeroTag(BookKind kind) => 'occasion_${kind.name}';

/// Header colours of an Occasion screen: the tile colour as a gradient.
(Color, Color) occasionHeader(BuildContext context, BookKind kind) {
  final bg = kind.tone.background(context);
  return (bg, Color.lerp(bg, kind.tone.icon(context), 0.22)!);
}

const _tileRadius = BorderRadius.all(Radius.circular(20));
const _headerRadius = BorderRadius.vertical(bottom: Radius.circular(32));

/// The background shared by an occasion tile and its screen's header. During
/// the route change it morphs (container transform): white card → tinted
/// header, radius 20 → bottom corners 32.
class OccasionHeroBackground extends StatelessWidget {
  const OccasionHeroBackground({
    required this.kind,
    required this.isHeader,
    super.key,
  });

  final BookKind kind;
  final bool isHeader;

  static Widget _decorated(BuildContext context, BookKind kind, double t) {
    final c = MemoriaColors.of(context);
    final (top, bottom) = occasionHeader(context, kind);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(c.surface, top, t)!,
            Color.lerp(c.surface, bottom, t)!,
          ],
        ),
        borderRadius: BorderRadius.lerp(_tileRadius, _headerRadius, t),
        border: t < 0.5 ? Border.all(color: c.border) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HeroMode(
      // Reduced motion: plain cross-fade between the screens.
      enabled: !Motion.reduced(context),
      child: Hero(
        tag: occasionHeroTag(kind),
        flightShuttleBuilder: (context, animation, direction, from, to) =>
            AnimatedBuilder(
              animation: animation,
              builder: (context, _) => _decorated(
                context,
                kind,
                Curves.easeInOutCubic.transform(animation.value),
              ),
            ),
        child: Material(
          type: MaterialType.transparency,
          child: _decorated(context, kind, isHeader ? 1 : 0),
        ),
      ),
    );
  }
}
