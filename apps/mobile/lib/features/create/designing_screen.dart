import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_config.dart';
import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../design/design.dart';
import '../../router/app_router.dart';
import 'creation_controller.dart';

/// "Designing your book…": an animated page stack while captions are
/// written and pages laid out (2–4 s; fake mode waits at least 1.5 s).
class DesigningScreen extends ConsumerStatefulWidget {
  const DesigningScreen({super.key});

  @override
  ConsumerState<DesigningScreen> createState() => _DesigningScreenState();
}

class _DesigningScreenState extends ConsumerState<DesigningScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  int _step = 0;
  Timer? _stepTimer;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Start after the first frame: providers can't change during build.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _anim.value = 0.5;
    } else if (!_anim.isAnimating) {
      _anim.repeat();
    }
  }

  Future<void> _run() async {
    setState(() => _failed = false);
    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (mounted && _step < 2) setState(() => _step++);
    });
    final config = ref.read(appConfigProvider);
    final minimum = Future<void>.delayed(
      config.useFakeBackend
          ? const Duration(milliseconds: 1500)
          : Duration.zero,
    );
    final id = await ref.read(creationControllerProvider.notifier).generate();
    await minimum;
    if (!mounted) return;
    if (id == null) {
      setState(() => _failed = true);
      return;
    }
    // The reveal, then the chosen edition on top of the editor.
    context.go(Routes.albumReveal(id));
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    if (_failed) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorState(
          title: l.errorGenericTitle,
          body: l.errorGenericBody,
          retryLabel: l.commonRetry,
          onRetry: _run,
        ),
      );
    }
    final steps = [l.designingChapters, l.designingWords, l.designingPages];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) =>
                        CustomPaint(painter: _PageStackPainter(_anim.value, c)),
                  ),
                ),
              ),
              const SizedBox(height: Space.xl),
              Semantics(
                liveRegion: true,
                child: Text(
                  l.designingTitle,
                  style: t.displaySmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: Space.lg),
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.xxs),
                  child: AnimatedOpacity(
                    duration: Motion.medium,
                    opacity: i <= _step ? 1 : 0.35,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          i < _step
                              ? Icons.check_rounded
                              : Icons.more_horiz_rounded,
                          size: 18,
                          color: i < _step ? c.secondary : c.textSecondary,
                        ),
                        const SizedBox(width: Space.xs),
                        Text(steps[i], style: t.bodyMedium),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: Space.xl),
              Text(AppConfig.brandName, style: t.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageStackPainter extends CustomPainter {
  _PageStackPainter(this.t, this.c);

  final double t;
  final MemoriaColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.62, h = size.height * 0.74;
    final center = size.center(Offset.zero);
    for (var i = 0; i < 4; i++) {
      final phase = (t + i / 4) % 1;
      final angle = (phase - 0.5) * 0.35 + (i - 1.5) * 0.06;
      final lift = math.sin(phase * math.pi) * 10;
      canvas.save();
      canvas.translate(center.dx, center.dy - lift);
      canvas.rotate(angle);
      final r = Rect.fromCenter(center: Offset.zero, width: w, height: h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          r.shift(const Offset(0, 5)),
          const Radius.circular(2),
        ),
        Paint()
          ..color = c.shadow.withValues(alpha: 0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(2)),
        Paint()..color = c.surfaceRaised,
      );
      // A tiny layout on each page.
      final photo = Rect.fromLTWH(
        r.left + w * 0.12,
        r.top + h * 0.12,
        w * 0.76,
        h * (i.isEven ? 0.5 : 0.36),
      );
      canvas.drawRect(
        photo,
        Paint()
          ..color = (i.isEven ? c.accent : c.secondary).withValues(alpha: 0.35),
      );
      final line = Paint()
        ..color = c.textSecondary.withValues(alpha: 0.4)
        ..strokeWidth = 1.2;
      canvas.drawLine(
        Offset(photo.left, photo.bottom + 10),
        Offset(photo.right - w * 0.2, photo.bottom + 10),
        line,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PageStackPainter old) => old.t != t;
}
