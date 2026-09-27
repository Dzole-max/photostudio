import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../design/design.dart';
import '../../domain/model/album.dart';
import '../../domain/spec/book_format.dart';
import '../book/book_page_view.dart';

/// The dark-blue hero: three fanned book covers above the headline, the
/// "Create a book" pill and a round play button for the explainer.
class HomeHero extends StatelessWidget {
  const HomeHero({
    required this.covers,
    required this.tilt,
    required this.onCreate,
    required this.onExplain,
    super.key,
  });

  /// The user's latest books (up to three); demo covers when empty.
  final List<Album> covers;

  /// −1..1 from the page scroll; the fan leans up to 6°.
  final ValueListenable<double> tilt;
  final VoidCallback onCreate;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = MemoriaColors.of(context);
    final t = Theme.of(context).textTheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Soft blue glow behind the card.
        Positioned(
          left: 24,
          right: 24,
          top: 40,
          bottom: 20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: Radii.heroAll,
              boxShadow: [
                BoxShadow(
                  color: c.primary.withValues(alpha: 0.35),
                  blurRadius: 60,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
        ),
        Container(
          height: 440,
          decoration: BoxDecoration(
            borderRadius: Radii.heroAll,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.heroFrom, c.heroTo],
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // A radial light behind the covers.
              Positioned(
                left: 0,
                right: 0,
                top: -60,
                height: 320,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        c.primaryOnDark.withValues(alpha: 0.28),
                        c.primaryOnDark.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 216,
                    child: ExcludeSemantics(
                      child: CoverFan(covers: covers, tilt: tilt),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.homeHeroLabel.toUpperCase(),
                            style: t.labelSmall?.copyWith(
                              color: c.primaryOnDark,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: Space.xs),
                          Text(
                            l.homeHeroTitle,
                            style: t.displaySmall?.copyWith(
                              color: c.textOnDark,
                              fontSize: 26,
                            ),
                          ),
                          const SizedBox(height: Space.xs),
                          Text(
                            l.homeHeroBody,
                            style: t.bodyMedium?.copyWith(
                              color: c.textOnDarkBody,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: c.primaryOnDark,
                                    foregroundColor: c.onPrimaryOnDark,
                                    minimumSize: const Size(0, 52),
                                  ),
                                  onPressed: onCreate,
                                  icon: const Icon(Icons.add_rounded),
                                  label: Text(l.homeCreateBook),
                                ),
                              ),
                              const SizedBox(width: Space.sm),
                              Semantics(
                                button: true,
                                label: l.homeHowItWorks,
                                child: Tooltip(
                                  message: l.homeHowItWorks,
                                  child: Material(
                                    color: c.textOnDark.withValues(alpha: 0.14),
                                    shape: CircleBorder(
                                      side: BorderSide(
                                        color: c.textOnDark.withValues(
                                          alpha: 0.24,
                                        ),
                                      ),
                                    ),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: onExplain,
                                      child: SizedBox(
                                        width: 52,
                                        height: 52,
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          color: c.textOnDark,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Three covers: the centre one upright, the sides rotated ±12° behind it.
/// They float slowly (±4 px over 6 s) and lean with the scroll.
class CoverFan extends StatefulWidget {
  const CoverFan({required this.covers, required this.tilt, super.key});

  final List<Album> covers;
  final ValueListenable<double> tilt;

  @override
  State<CoverFan> createState() => _CoverFanState();
}

class _CoverFanState extends State<CoverFan>
    with SingleTickerProviderStateMixin {
  late final _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  Widget _cover(int i) {
    final covers = widget.covers;
    if (i < covers.length) return _AlbumCover(album: covers[i]);
    return DemoCover(kind: DemoCoverKind.values[i % 3]);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = Motion.reduced(context);
    return AnimatedBuilder(
      animation: Listenable.merge([_float, widget.tilt]),
      builder: (context, _) {
        final phase = _float.value * 2 * math.pi;
        final lean = reduce ? 0.0 : widget.tilt.value * 6 * math.pi / 180;
        Widget placed(int i, double dx, double angle, double scale, double p) {
          final bob = reduce ? 0.0 : math.sin(phase + p) * 4;
          return Transform.translate(
            offset: Offset(dx, bob + (angle == 0 ? 0 : 14)),
            child: Transform.rotate(
              angle: angle,
              child: Transform.scale(scale: scale, child: _cover(i)),
            ),
          );
        }

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateX(lean),
          child: Stack(
            alignment: Alignment.center,
            children: [
              placed(1, -84, -12 * math.pi / 180, 0.86, 1.2),
              placed(2, 84, 12 * math.pi / 180, 0.86, 2.4),
              placed(0, 0, 0, 1, 0),
            ],
          ),
        );
      },
    );
  }
}

/// A book's real front cover, with a spine shadow and a soft drop shadow.
class _AlbumCover extends StatelessWidget {
  const _AlbumCover({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final aspect = BookFormat.byId(album.formatId).aspect;
    // Fits a 128 × 160 box.
    final w = math.min(128.0, 160 * aspect);
    return _CoverFrame(
      width: w,
      height: w / aspect,
      child: BookPageView(album: album, page: album.cover.front),
    );
  }
}

class _CoverFrame extends StatelessWidget {
  const _CoverFrame({
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66020A1C),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          // Spine: a hinge shadow down the left edge.
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0x40000000),
                    Color(0x10FFFFFF),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum DemoCoverKind { monogram, sea, story }

/// Designed covers for an empty shelf: a gold-tone monogram, a summer sea,
/// and "Your story".
class DemoCover extends StatelessWidget {
  const DemoCover({required this.kind, super.key});

  final DemoCoverKind kind;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _CoverFrame(
      width: 124,
      height: 158,
      child: switch (kind) {
        DemoCoverKind.monogram => ColoredBox(
          color: const Color(0xFFF4EFE6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFB8955A),
                    width: 1.2,
                  ),
                ),
                child: const Text(
                  'A & E',
                  style: TextStyle(
                    fontFamily: Fonts.greatVibes,
                    fontSize: 20,
                    color: Color(0xFFB8955A),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(width: 26, height: 1, color: const Color(0xFFB8955A)),
            ],
          ),
        ),
        DemoCoverKind.sea => DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF8CC8F0), Color(0xFFE6F3FB)],
              stops: [0, 0.6],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 18,
                top: 22,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFFE29A),
                  ),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 62,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF2C8FC7), Color(0xFF1B5E91)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 70,
                child: Text(
                  l.demoCoverSummer.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: Fonts.manrope,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 4,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        DemoCoverKind.story => ColoredBox(
          color: const Color(0xFF13294F),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0x66E9DDC4)),
              ),
              child: Center(
                child: Text(
                  l.demoCoverStory,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: Fonts.cormorant,
                    fontStyle: FontStyle.italic,
                    fontSize: 20,
                    color: Color(0xFFE9DDC4),
                  ),
                ),
              ),
            ),
          ),
        ),
      },
    );
  }
}
