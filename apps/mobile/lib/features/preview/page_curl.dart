import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Half-plane clip helper: polygon of [rect] on the side of the line through
/// [q] with normal [n] where (p − q)·n ≥ 0.
Path halfPlane(Rect rect, Offset q, Offset n) {
  final pts = [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft];
  double side(Offset p) => (p.dx - q.dx) * n.dx + (p.dy - q.dy) * n.dy;
  final out = <Offset>[];
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i], b = pts[(i + 1) % pts.length];
    final sa = side(a), sb = side(b);
    if (sa >= 0) out.add(a);
    if ((sa >= 0) != (sb >= 0)) {
      final t = sa / (sa - sb);
      out.add(Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t));
    }
  }
  final path = Path();
  if (out.length >= 3) path.addPolygon(out, true);
  return path;
}

/// Reflection across the line through [q] with unit direction [d].
Matrix4 reflection(Offset q, Offset d) {
  final a = d.dx * d.dx - d.dy * d.dy;
  final b = 2 * d.dx * d.dy;
  final m = Matrix4.identity()
    ..setEntry(0, 0, a)
    ..setEntry(0, 1, b)
    ..setEntry(1, 0, b)
    ..setEntry(1, 1, -a);
  return Matrix4.translationValues(
    q.dx,
    q.dy,
    0,
  ).multiplied(m).multiplied(Matrix4.translationValues(-q.dx, -q.dy, 0));
}

class _PathClipper extends CustomClipper<Path> {
  _PathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_PathClipper old) => true;
}

/// An open book whose right (or left) page can be dragged over like paper:
/// the sheet folds along the perpendicular bisector of the corner and the
/// drag point, the back of the sheet shows the next page, and the fold
/// casts a soft shadow. [pages] builds a page widget by index (null = blank).
class PageCurlBook extends StatefulWidget {
  const PageCurlBook({
    required this.spreadCount,
    required this.pageBuilder,
    required this.pageAspect,
    this.onTurn,
    this.flat = false,
    this.semanticsPrevious = '',
    this.semanticsNext = '',
    super.key,
  });

  /// Number of spreads; spread i shows pages (left, right) from [spreadPages].
  final int spreadCount;

  /// Builds the page widget for spread [spread], side left/right.
  final Widget Function(int spread, bool right) pageBuilder;
  final double pageAspect;
  final ValueChanged<int>? onTurn;

  /// Reduce motion / slow devices: a flat slide instead of the curl.
  final bool flat;
  final String semanticsPrevious;
  final String semanticsNext;

  @override
  State<PageCurlBook> createState() => _PageCurlBookState();
}

class _PageCurlBookState extends State<PageCurlBook>
    with SingleTickerProviderStateMixin {
  int _spread = 0;

  /// Drag point in spread coordinates, null when idle.
  Offset? _drag;
  bool _forward = true;
  bool _fromTop = false;
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  Offset? _animFrom;
  Offset? _animTo;
  bool _completing = false;
  Size _size = Size.zero;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  double get _w => _size.width / 2;
  double get _h => _size.height;

  Offset get _corner => _forward
      ? Offset(2 * _w, _fromTop ? 0 : _h)
      : Offset(0, _fromTop ? 0 : _h);

  Offset get _target => _forward
      ? Offset(0, _fromTop ? 0 : _h)
      : Offset(2 * _w, _fromTop ? 0 : _h);

  /// Paper can't stretch: keep the drag point within one page width of the
  /// spine anchor on the corner's edge.
  Offset _constrain(Offset p) {
    final anchor = Offset(_w, _fromTop ? 0 : _h);
    final v = p - anchor;
    final d = v.distance;
    if (d <= _w) return p;
    return anchor + v / d * _w;
  }

  bool get _canForward => _spread < widget.spreadCount - 1;
  bool get _canBack => _spread > 0;

  void _start(Offset local) {
    if (_anim.isAnimating) return;
    final forward = local.dx > _w;
    if (forward && !_canForward || !forward && !_canBack) return;
    setState(() {
      _forward = forward;
      _fromTop = local.dy < _h / 2;
      _drag = _constrain(local);
    });
  }

  void _update(Offset local) {
    if (_drag == null || _anim.isAnimating) return;
    setState(() => _drag = _constrain(local));
  }

  Future<void> _end() async {
    final drag = _drag;
    if (drag == null) return;
    final done = _forward ? drag.dx < _w : drag.dx > _w;
    await _animate(drag, done ? _target : _corner, complete: done);
  }

  Future<void> _animate(
    Offset from,
    Offset to, {
    required bool complete,
  }) async {
    _animFrom = from;
    _animTo = to;
    _completing = complete;
    _anim.value = 0;
    await _anim.animateTo(1, curve: Curves.easeOutCubic);
    if (!mounted) return;
    setState(() {
      if (_completing) {
        _spread += _forward ? 1 : -1;
        widget.onTurn?.call(_spread);
        HapticFeedback.lightImpact();
      }
      _drag = null;
      _animFrom = null;
    });
  }

  Future<void> turn(bool forward) async {
    if (_anim.isAnimating || _drag != null) return;
    if (forward && !_canForward || !forward && !_canBack) return;
    setState(() {
      _forward = forward;
      _fromTop = false;
    });
    final start = _corner + Offset(forward ? -1 : 1, -1);
    setState(() => _drag = start);
    await _animate(start, _target, complete: true);
  }

  Offset? get _current {
    if (_animFrom != null && _animTo != null) {
      final t = _anim.value;
      final raw = Offset.lerp(_animFrom, _animTo, t)!;
      // Lift the paper slightly mid-turn for a curl-like arc.
      final lift = math.sin(t * math.pi) * _h * 0.06;
      return _constrain(raw - Offset(0, _fromTop ? -lift : lift));
    }
    return _drag;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flat) return _flat(context);
    return AspectRatio(
      aspectRatio: widget.pageAspect * 2,
      child: LayoutBuilder(
        builder: (context, box) {
          _size = Size(box.maxWidth, box.maxHeight);
          return GestureDetector(
            onPanStart: (d) => _start(d.localPosition),
            onPanUpdate: (d) => _update(d.localPosition),
            onPanEnd: (_) => _end(),
            onTapUp: (d) {
              if (d.localPosition.dx > _w * 1.7) unawaited(turn(true));
              if (d.localPosition.dx < _w * 0.3) unawaited(turn(false));
            },
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) => _stack(),
            ),
          );
        },
      ),
    );
  }

  Widget _page(int spread, bool right) {
    if (spread < 0 || spread >= widget.spreadCount) {
      return const SizedBox.shrink();
    }
    return RepaintBoundary(child: widget.pageBuilder(spread, right));
  }

  Widget _stack() {
    final w = _w, h = _h;
    final leftRect = Rect.fromLTWH(0, 0, w, h);
    final rightRect = Rect.fromLTWH(w, 0, w, h);
    final p = _current;
    final base = <Widget>[
      Positioned.fromRect(rect: leftRect, child: _page(_spread, false)),
      Positioned.fromRect(rect: rightRect, child: _page(_spread, true)),
    ];
    if (p == null) {
      return Stack(
        children: [
          ...base,
          _gutter(w, h),
          const Positioned.fill(child: _PaperTexture()),
        ],
      );
    }
    final c = _corner;
    final mid = (c + p) / 2;
    var dir = c - p;
    if (dir.distance < 0.5) dir = Offset(_forward ? 1 : -1, 0);
    final n = dir / dir.distance; // normal pointing towards the corner
    final along = Offset(-n.dy, n.dx); // fold line direction
    final sheetRect = _forward ? rightRect : leftRect;
    final lifted = halfPlane(sheetRect, mid, n);
    final flat = halfPlane(sheetRect, mid, -n);
    final next = _spread + (_forward ? 1 : -1);
    final m = reflection(mid, along);
    // Mirror about the spine so the sheet's back reads correctly once turned.
    final mirror = Matrix4.translationValues(
      2 * w,
      0,
      0,
    ).multiplied(Matrix4.diagonal3Values(-1, 1, 1));
    final backRect = _forward ? leftRect : rightRect;

    return Stack(
      children: [
        // The static page on the other side and the page being revealed.
        Positioned.fromRect(
          rect: _forward ? leftRect : rightRect,
          child: _page(_spread, !_forward),
        ),
        Positioned.fill(
          child: ClipPath(
            clipper: _PathClipper(lifted),
            child: Stack(
              children: [
                Positioned.fromRect(
                  rect: sheetRect,
                  child: _page(next, _forward),
                ),
                Positioned.fill(
                  child: CustomPaint(painter: _FoldShadow(mid, n, w)),
                ),
              ],
            ),
          ),
        ),
        // The part of the sheet still lying flat.
        Positioned.fill(
          child: ClipPath(
            clipper: _PathClipper(flat),
            child: Stack(
              children: [
                Positioned.fromRect(
                  rect: sheetRect,
                  child: _page(_spread, _forward),
                ),
              ],
            ),
          ),
        ),
        _gutter(w, h),
        // The folded-over flap showing the back of the sheet.
        Positioned.fill(
          child: Transform(
            transform: m,
            child: ClipPath(
              clipper: _PathClipper(lifted),
              child: Transform(
                transform: mirror,
                child: Stack(
                  children: [
                    Positioned.fromRect(
                      rect: backRect,
                      child: _page(next, !_forward),
                    ),
                    Positioned.fromRect(
                      rect: backRect,
                      child: CustomPaint(
                        painter: _FlapShade(mid, n, w, mirror),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Positioned.fill(child: IgnorePointer(child: _PaperTexture())),
      ],
    );
  }

  Widget _gutter(double w, double h) => Positioned(
    left: w - w * 0.06,
    width: w * 0.12,
    top: 0,
    bottom: 0,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0),
              Colors.black.withValues(alpha: 0.12),
              Colors.black.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _flat(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.pageAspect * 2,
      child: PageView.builder(
        itemCount: widget.spreadCount,
        onPageChanged: (i) {
          _spread = i;
          widget.onTurn?.call(i);
        },
        itemBuilder: (context, i) => Row(
          children: [
            Expanded(child: _page(i, false)),
            Expanded(child: _page(i, true)),
          ],
        ),
      ),
    );
  }
}

class _FoldShadow extends CustomPainter {
  _FoldShadow(this.q, this.n, this.w);

  final Offset q;
  final Offset n;
  final double w;

  @override
  void paint(Canvas canvas, Size size) {
    final end = q + n * w * 0.35;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(q, end, [
          Colors.black.withValues(alpha: 0.28),
          Colors.black.withValues(alpha: 0),
        ]),
    );
  }

  @override
  bool shouldRepaint(_FoldShadow old) => old.q != q || old.n != n;
}

/// Shading on the flap: darker near the fold, like paper curving.
class _FlapShade extends CustomPainter {
  _FlapShade(this.q, this.n, this.w, this.mirror);

  final Offset q;
  final Offset n;
  final double w;
  final Matrix4 mirror;

  @override
  void paint(Canvas canvas, Size size) {
    // In flap space the fold lies at the mirrored position of q.
    final fold = MatrixUtils.transformPoint(mirror, q);
    final dir = Offset(-n.dx, n.dy);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          fold,
          fold + dir * w * 0.5,
          [
            Colors.black.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.06),
            Colors.black.withValues(alpha: 0.04),
          ],
          [0, 0.4, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_FlapShade old) => old.q != q || old.n != n;
}

/// Paper texture multiplied at 4 % over the pages.
class _PaperTexture extends StatelessWidget {
  const _PaperTexture();

  static ui.Picture? _picture;

  static ui.Picture _build() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rng = math.Random(11);
    final paint = Paint()..color = const Color(0xFF6B635A);
    for (var i = 0; i < 2600; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * 512, rng.nextDouble() * 512),
        rng.nextDouble() * 0.9,
        paint,
      );
    }
    return recorder.endRecording();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.04,
        child: CustomPaint(painter: _TexturePainter(_picture ??= _build())),
      ),
    );
  }
}

class _TexturePainter extends CustomPainter {
  _TexturePainter(this.picture);

  final ui.Picture picture;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..blendMode = BlendMode.multiply,
    );
    for (double y = 0; y < size.height; y += 512) {
      for (double x = 0; x < size.width; x += 512) {
        canvas.save();
        canvas.translate(x, y);
        canvas.drawPicture(picture);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TexturePainter oldDelegate) => false;
}
