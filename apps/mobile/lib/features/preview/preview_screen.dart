import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/domain_kit.dart';
import '../../data/settings/settings.dart';
import '../../design/design.dart';
import '../../domain/model/album.dart';
import '../../domain/pricing/pricing.dart';
import '../../domain/spec/book_format.dart';
import '../../router/app_router.dart';
import '../book/book_page_view.dart';
import '../editor/editor_controller.dart';
import '../editor/panels/format_panel.dart';
import 'page_curl.dart';

enum PreviewMode { closed, open, table }

class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({required this.albumId, super.key});

  final String albumId;

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  PreviewMode _mode = PreviewMode.closed;
  bool _softProof = false;
  double _yaw = -0.35;
  double _pitch = 0.12;
  bool _backSide = false;
  bool _slowFrames = false;
  final List<bool> _recent = [];

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  /// Falls back to flat pages when frames repeatedly take over 20 ms.
  void _onTimings(List<ui.FrameTiming> timings) {
    if (_mode != PreviewMode.open || _slowFrames) return;
    for (final t in timings) {
      _recent.add(t.totalSpan > const Duration(milliseconds: 20));
      if (_recent.length > 30) _recent.removeAt(0);
    }
    if (_recent.length >= 30 &&
        _recent.where((s) => s).length > 20 &&
        mounted) {
      setState(() => _slowFrames = true);
    }
  }

  bool _fromEditor(BuildContext context) {
    final matches = GoRouter.of(context).routerDelegate.currentConfiguration;
    return matches.matches.any(
      (m) => m.matchedLocation == Routes.album(widget.albumId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final state = ref.watch(editorControllerProvider(widget.albumId)).value;
    final kit = ref.watch(domainKitProvider).value;
    if (state == null || kit == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final album = state.album;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final price = priceBook(
      catalog: kit.fakeCatalog,
      formatId: album.formatId,
      innerPages: album.pages.length,
      finish: album.coverFinish,
    );
    final reduce = Motion.reduced(context);

    final Widget body = switch (_mode) {
      PreviewMode.closed => _ClosedBook(
        album: album,
        yaw: _yaw + (_backSide ? math.pi : 0),
        pitch: _pitch,
        softProof: _softProof,
        onDrag: (d) => setState(() {
          _yaw = (_yaw + d.dx / 200).clamp(
            -35 * math.pi / 180,
            35 * math.pi / 180,
          );
          _pitch = (_pitch - d.dy / 300).clamp(
            -15 * math.pi / 180,
            15 * math.pi / 180,
          );
        }),
        onTap: () => setState(() => _mode = PreviewMode.open),
      ),
      PreviewMode.open => _OpenBook(
        album: album,
        softProof: _softProof,
        flat: reduce || _slowFrames,
        sound: ref.watch(
          settingsControllerProvider.select((s) => s.pageTurnSound),
        ),
      ),
      PreviewMode.table => _TableView(album: album),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l.previewTitle),
        actions: [
          if (_mode == PreviewMode.closed)
            TextButton(
              onPressed: () => setState(() => _backSide = !_backSide),
              child: Text(l.previewTurnOver),
            ),
          // Opened from the shelf: the editor is not underneath.
          if (!_fromEditor(context))
            IconButton(
              tooltip: l.commonEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.go(Routes.album(widget.albumId)),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: SegmentedButton<PreviewMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: PreviewMode.closed,
                    label: Text(l.previewBook),
                    icon: const Icon(Icons.menu_book_outlined),
                  ),
                  ButtonSegment(
                    value: PreviewMode.open,
                    label: Text(l.tabPages),
                    icon: const Icon(Icons.auto_stories_outlined),
                  ),
                  ButtonSegment(
                    value: PreviewMode.table,
                    label: Text(l.previewTable),
                    icon: const Icon(Icons.table_restaurant_outlined),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: body,
                ),
              ),
            ),
            if (_mode == PreviewMode.closed)
              Text(l.previewOpen, style: t.bodySmall)
            else if (_mode == PreviewMode.open)
              Text(l.previewTurnHint, style: t.bodySmall)
            else
              Text(l.previewCupHint, style: t.bodySmall),
            if (_mode != PreviewMode.table)
              SwitchListTile(
                value: _softProof,
                onChanged: (v) => setState(() => _softProof = v),
                title: Text(l.previewSoftProof, style: t.bodyMedium),
                dense: true,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                0,
                Space.md,
                Space.md,
              ),
              child: PrimaryButton(
                label: l.previewOrder(
                  money(price.bookCents, price.currency, locale),
                ),
                onPressed: () {
                  if (!state.report.canOrder) {
                    context.push(Routes.albumCheck(widget.albumId));
                  } else {
                    context.push(Routes.albumCheckout(widget.albumId));
                  }
                },
              ),
            ),
            ColoredBox(color: c.background),
          ],
        ),
      ),
    );
  }
}

/// A closed book as a small 3D box: front, spine and back faces, rotated by
/// drag within ±35° yaw and ±15° pitch.
class _ClosedBook extends StatelessWidget {
  const _ClosedBook({
    required this.album,
    required this.yaw,
    required this.pitch,
    required this.softProof,
    required this.onDrag,
    required this.onTap,
  });

  final Album album;
  final double yaw;
  final double pitch;
  final bool softProof;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = BookFormat.byId(album.formatId);
    return LayoutBuilder(
      builder: (context, box) {
        final w = math.min(
          box.maxWidth * 0.62,
          box.maxHeight * 0.72 * f.aspect,
        );
        final h = w / f.aspect;
        final thick = math.max(10.0, w * album.cover.spineMm / f.trimWMm * 2.2);
        Matrix4 base() => Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateX(pitch)
          ..rotateY(yaw);
        Widget face(Matrix4 m, double fw, Widget child) => Transform(
          alignment: Alignment.center,
          transform: base()..multiply(m),
          child: SizedBox(width: fw, height: h, child: child),
        );
        // Which faces point at the viewer.
        final frontVisible = math.cos(yaw) > 0;
        final spineVisible = math.sin(yaw) > 0.02;
        final front = face(
          Matrix4.translationValues(0, 0, -thick / 2),
          w,
          BookPageView(
            album: album,
            page: album.cover.front,
            softProof: softProof,
            semanticLabel: l.editorCover,
          ),
        );
        final back = face(
          Matrix4.translationValues(0, 0, thick / 2)..rotateY(math.pi),
          w,
          BookPageView(
            album: album,
            page: album.cover.back,
            softProof: softProof,
            semanticLabel: l.checkBackCover,
          ),
        );
        final spine = face(
          Matrix4.translationValues(-w / 2, 0, 0)..rotateY(math.pi / 2),
          thick,
          RotatedBox(
            quarterTurns: 0,
            child: BookPageView(
              album: album,
              page: album.cover.spine,
              widthMm: math.max(album.cover.spineMm, 1),
              softProof: softProof,
              semanticLabel: l.checkSpine,
            ),
          ),
        );
        return GestureDetector(
          onPanUpdate: (d) => onDrag(d.delta),
          onTap: onTap,
          child: SizedBox(
            width: w + thick * 2,
            height: h + 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  bottom: 0,
                  left: w * 0.1,
                  right: w * 0.1,
                  height: 24,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                  ),
                ),
                if (spineVisible) spine,
                if (frontVisible) front else back,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OpenBook extends StatelessWidget {
  const _OpenBook({
    required this.album,
    required this.softProof,
    required this.flat,
    required this.sound,
  });

  final Album album;
  final bool softProof;
  final bool flat;
  final bool sound;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = BookFormat.byId(album.formatId);
    final n = album.pages.length;
    // Spread 0: blank left + page 0; then (1,2), (3,4)...; last (n-1, blank).
    final spreads = <(int?, int?)>[(null, 0)];
    for (var left = 1; left < n; left += 2) {
      spreads.add((left, left + 1 < n ? left + 1 : null));
    }
    Widget pageWidget(int spread, bool right) {
      final (a, b) = spreads[spread];
      final index = right ? b : a;
      if (index == null) {
        // Endpaper.
        return const ColoredBox(
          color: Color(0xFFF4EFE6),
          child: SizedBox.expand(),
        );
      }
      return BookPageView(
        album: album,
        page: album.pages[index],
        softProof: softProof,
        semanticLabel: l.editorPage(index + 1),
      );
    }

    return PageCurlBook(
      spreadCount: spreads.length,
      pageAspect: f.aspect,
      flat: flat,
      pageBuilder: pageWidget,
      onTurn: (_) {
        if (sound) SystemSound.play(SystemSoundType.click);
      },
    );
  }
}

/// The book on an oak table beside a coffee cup, at true relative scale.
class _TableView extends StatelessWidget {
  const _TableView({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final f = BookFormat.byId(album.formatId);
    return LayoutBuilder(
      builder: (context, box) {
        // The table shows 480 mm across.
        final s = box.maxWidth / 480;
        return ClipRRect(
          borderRadius: Radii.cardAll,
          child: SizedBox(
            width: box.maxWidth,
            height: math.min(box.maxHeight, 360 * s),
            child: CustomPaint(
              painter: _OakPainter(),
              child: Stack(
                children: [
                  Positioned(
                    left: 40 * s,
                    top: 40 * s,
                    width: f.trimWMm * s,
                    height: f.trimHMm * s,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 18 * s,
                            offset: Offset(6 * s, 8 * s),
                          ),
                        ],
                      ),
                      child: BookPageView(
                        album: album,
                        page: album.cover.front,
                      ),
                    ),
                  ),
                  // Coffee cup (Ø 85 mm) on a saucer (Ø 140 mm).
                  Positioned(
                    left: (40 + f.trimWMm + 30) * s,
                    top: 60 * s,
                    width: 140 * s,
                    height: 140 * s,
                    child: CustomPaint(painter: _CupPainter()),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OakPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFB8895A), Color(0xFFA7784B), Color(0xFFBE9164)],
        ).createShader(rect),
    );
    final rng = math.Random(4);
    for (var i = 0; i < 70; i++) {
      final y = rng.nextDouble() * size.height;
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= size.width; x += size.width / 12) {
        path.lineTo(
          x,
          y +
              math.sin(x / size.width * math.pi * 2 + i) * 4 +
              rng.nextDouble() * 2,
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rng.nextDouble() * 1.6 + 0.3
          ..color = const Color(0xFF7A5230)
              .withValues(alpha: rng.nextDouble() * 0.25),
      );
    }
  }

  @override
  bool shouldRepaint(_OakPainter oldDelegate) => false;
}

class _CupPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final saucer = size.width / 2;
    final cup = saucer * 85 / 140;
    canvas.drawCircle(
      c + const Offset(4, 6),
      saucer,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(c, saucer, Paint()..color = const Color(0xFFF4EFE6));
    canvas.drawCircle(
      c,
      saucer * 0.92,
      Paint()
        ..color = const Color(0xFFE9E1D3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(c, cup, Paint()..color = const Color(0xFFFBF8F2));
    canvas.drawCircle(c, cup * 0.82, Paint()..color = const Color(0xFF5B3A22));
    canvas.drawCircle(
      c + Offset(-cup * 0.2, -cup * 0.25),
      cup * 0.2,
      Paint()..color = const Color(0xFFB88D5A).withValues(alpha: 0.6),
    );
    final handle = Rect.fromCenter(
      center: c + Offset(cup + cup * 0.18, 0),
      width: cup * 0.36,
      height: cup * 0.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(handle, Radius.circular(cup * 0.2)),
      Paint()
        ..color = const Color(0xFFFBF8F2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cup * 0.1,
    );
  }

  @override
  bool shouldRepaint(_CupPainter oldDelegate) => false;
}
