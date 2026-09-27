import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../design/design.dart';
import '../home/home_hero.dart';

/// "See how it works": a 20-second explainer in four scenes (pick, design,
/// cover, hold), story-style. Tap the right half to skip ahead, the left
/// half to go back.
class ExplainerScreen extends StatefulWidget {
  const ExplainerScreen({super.key});

  @override
  State<ExplainerScreen> createState() => _ExplainerScreenState();
}

const _scenes = 4;

class _ExplainerScreenState extends State<ExplainerScreen>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  );

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) context.pop();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _jump(int delta) {
    HapticFeedback.selectionClick();
    final scene = (_c.value * _scenes).floor() + delta;
    if (scene >= _scenes) {
      context.pop();
      return;
    }
    _c.value = (scene.clamp(0, _scenes - 1)) / _scenes;
    _c.forward();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final titles = [
      (l.explainerScene1, l.explainerScene1Body),
      (l.explainerScene2, l.explainerScene2Body),
      (l.explainerScene3, l.explainerScene3Body),
      (l.explainerScene4, l.explainerScene4Body),
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.heroFrom, c.heroTo],
            ),
          ),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final pos = _c.value * _scenes;
                final scene = pos.floor().clamp(0, _scenes - 1);
                final local = (pos - scene).clamp(0.0, 1.0);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _jump(
                    d.localPosition.dx > MediaQuery.sizeOf(context).width / 3
                        ? 1
                        : -1,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Space.md,
                          Space.sm,
                          Space.xs,
                          0,
                        ),
                        child: Row(
                          children: [
                            for (var i = 0; i < _scenes; i++) ...[
                              if (i > 0) const SizedBox(width: 4),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: Radii.pillAll,
                                  child: LinearProgressIndicator(
                                    minHeight: 3,
                                    value: i < scene
                                        ? 1
                                        : (i == scene ? local : 0),
                                    color: c.textOnDark,
                                    backgroundColor: c.textOnDark.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            IconButton(
                              tooltip: l.commonClose,
                              onPressed: () => context.pop(),
                              icon: Icon(
                                Icons.close_rounded,
                                color: c.textOnDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ExcludeSemantics(
                          child: Center(
                            child: switch (scene) {
                              0 => _PickScene(local),
                              1 => _DesignScene(local),
                              2 => _CoverScene(local),
                              _ => _HoldScene(local),
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Space.lg,
                          0,
                          Space.lg,
                          Space.xl,
                        ),
                        child: Semantics(
                          liveRegion: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.homeStepOf(scene + 1, _scenes).toUpperCase(),
                                style: t.labelSmall?.copyWith(
                                  color: c.primaryOnDark,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: Space.xs),
                              Text(
                                titles[scene].$1,
                                style: t.displaySmall?.copyWith(
                                  color: c.textOnDark,
                                ),
                              ),
                              const SizedBox(height: Space.xs),
                              Text(
                                titles[scene].$2,
                                style: t.bodyLarge?.copyWith(
                                  color: c.textOnDarkBody,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

const _photos = [
  'assets/samples/travel/t05.jpg',
  'assets/samples/travel/t06.jpg',
  'assets/samples/travel/t09.jpg',
  'assets/samples/travel/t03.jpg',
  'assets/samples/travel/t13.jpg',
  'assets/samples/travel/t04.jpg',
  'assets/samples/travel/t08.jpg',
  'assets/samples/travel/t14.jpg',
  'assets/samples/travel/t16.jpg',
];

Widget _photo(int i, {double radius = 8}) => ClipRRect(
  borderRadius: BorderRadius.circular(radius),
  child: Image.asset(
    _photos[i % _photos.length],
    fit: BoxFit.cover,
    cacheWidth: 360,
  ),
);

double _step(double t, double at, [double span = 0.12]) =>
    Curves.easeOutBack.transform(((t - at) / span).clamp(0.0, 1.0));

/// Photos arrive; two blurry ones step aside.
class _PickScene extends StatelessWidget {
  const _PickScene(this.t);

  final double t;

  @override
  Widget build(BuildContext context) {
    final c = MemoriaColors.of(context);
    return SizedBox(
      width: 300,
      height: 300,
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 9; i++)
            Builder(
              builder: (context) {
                final s = _step(t, i * 0.05);
                final aside = (i == 2 || i == 7) && t > 0.6;
                return Transform.scale(
                  scale: s.clamp(0.0, 1.2),
                  child: AnimatedOpacity(
                    duration: Motion.medium,
                    opacity: aside ? 0.3 : 1,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _photo(i),
                        if (aside)
                          Center(
                            child: Icon(
                              Icons.blur_on_rounded,
                              color: c.textOnDark,
                              size: 32,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// An open spread fills itself: photos drop into frames, then a caption.
class _DesignScene extends StatelessWidget {
  const _DesignScene(this.t);

  final double t;

  @override
  Widget build(BuildContext context) {
    Widget page(List<Widget> children) => Container(
      width: 150,
      height: 190,
      padding: const EdgeInsets.all(10),
      color: const Color(0xFFF7F3EC),
      child: Column(children: children),
    );
    Widget slot(int i, double at, {double h = 80}) => SizedBox(
      height: h,
      width: double.infinity,
      child: Transform.scale(
        scale: _step(t, at).clamp(0.0, 1.2),
        child: _photo(i, radius: 2),
      ),
    );
    final caption = ((t - 0.6) / 0.2).clamp(0.0, 1.0);
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [BoxShadow(color: Color(0x66020A1C), blurRadius: 40)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          page([
            slot(0, 0.05, h: 110),
            const SizedBox(height: 8),
            Opacity(
              opacity: caption,
              child: Column(
                children: [
                  Container(
                    height: 5,
                    width: 90,
                    color: const Color(0xFF1F1B17),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 3,
                    width: 110,
                    color: const Color(0x661F1B17),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 3,
                    width: 80,
                    color: const Color(0x661F1B17),
                  ),
                ],
              ),
            ),
          ]),
          Container(width: 2, height: 190, color: const Color(0x22000000)),
          page([
            slot(1, 0.2),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: slot(2, 0.32, h: 70)),
                const SizedBox(width: 8),
                Expanded(child: slot(3, 0.44, h: 70)),
              ],
            ),
          ]),
        ],
      ),
    );
  }
}

/// Four covers fan out; the choice moves between them.
class _CoverScene extends StatelessWidget {
  const _CoverScene(this.t);

  final double t;

  @override
  Widget build(BuildContext context) {
    final c = MemoriaColors.of(context);
    final chosen = (t * 3).floor().clamp(0, 2);
    final spread = Curves.easeOutCubic.transform((t / 0.3).clamp(0.0, 1.0));
    Widget cover(int i) => switch (i) {
      0 => const DemoCover(kind: DemoCoverKind.monogram),
      1 => SizedBox(width: 124, height: 158, child: _photo(4, radius: 4)),
      _ => const DemoCover(kind: DemoCoverKind.sea),
    };
    return SizedBox(
      width: 340,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final i in [0, 2, 1])
            Transform.translate(
              offset: Offset((i - 1) * 104 * spread, i == chosen ? -10 : 0),
              child: Transform.rotate(
                angle: (i - 1) * 0.12 * spread,
                child: AnimatedContainer(
                  duration: Motion.short,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: i == chosen ? c.primaryOnDark : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: cover(i),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The finished book turns slowly in the light.
class _HoldScene extends StatelessWidget {
  const _HoldScene(this.t);

  final double t;

  @override
  Widget build(BuildContext context) {
    final c = MemoriaColors.of(context);
    final yaw = -0.5 + 0.4 * math.sin(t * math.pi);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(yaw),
          child: Transform.scale(
            scale: 1.4,
            child: const DemoCover(kind: DemoCoverKind.story),
          ),
        ),
        const SizedBox(height: 56),
        Opacity(
          opacity: ((t - 0.4) / 0.3).clamp(0.0, 1.0),
          child: Icon(
            Icons.local_shipping_outlined,
            color: c.primaryOnDark,
            size: 36,
          ),
        ),
      ],
    );
  }
}
