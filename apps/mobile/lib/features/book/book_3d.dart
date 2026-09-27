import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../domain/model/album.dart';
import '../../domain/spec/book_format.dart';
import 'book_page_view.dart';
import 'cover_material.dart';

/// A closed book as a small 3D box: front cover, spine and back cover, each
/// the real rendered panel, with light falloff, a page block on the fore
/// edge, the cover material's texture, and a soft contact shadow.
class Book3D extends StatelessWidget {
  const Book3D({
    required this.album,
    required this.width,
    this.yaw = -0.35,
    this.pitch = 0.1,
    this.open = 0,
    this.softProof = false,
    this.finish,
    this.semanticLabel,
    this.glint,
    this.glintColor = const Color(0xFFFFFFFF),
    super.key,
  });

  final Album album;

  /// Width of the front cover in logical pixels.
  final double width;

  /// Rotation around the vertical axis (radians); negative shows the spine.
  final double yaw;
  final double pitch;

  /// 0 = closed, 1 = cover swung fully open (used for "open into preview").
  final double open;
  final bool softProof;

  /// Overrides the album's cover finish (material picker).
  final CoverFinish? finish;
  final String? semanticLabel;

  /// A band of light across the front cover at this position (0..1, left
  /// to right); null for none. Used by the reveal.
  final double? glint;
  final Color glintColor;

  @override
  Widget build(BuildContext context) {
    final f = BookFormat.byId(album.formatId);
    final w = width;
    final h = w / f.aspect;
    final thick = math.max(16.0, w * album.cover.spineMm / f.trimWMm * 3.2);
    final material = finish ?? album.coverFinish;
    Matrix4 base() => Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateX(pitch)
      ..rotateY(yaw);
    Widget face(Matrix4 m, double fw, Widget child) => Transform(
      alignment: Alignment.center,
      transform: base()..multiply(m),
      child: SizedBox(width: fw, height: h, child: child),
    );
    final c = math.cos(yaw), s = math.sin(yaw);
    // Light from the upper left: faces turned away get darker.
    final frontShade = (0.18 * (1 - c)).clamp(0.0, 0.3);
    final spineShade = (0.1 + 0.2 * (1 - s.abs())).clamp(0.0, 0.35);

    final coverFront = CoverMaterialOverlay(
      finish: material,
      sheen: 0.5 + yaw,
      child: BookPageView(
        album: album,
        page: album.cover.front,
        softProof: softProof,
      ),
    );
    final front = face(
      Matrix4.translationValues(0, 0, -thick / 2),
      w,
      Stack(
        fit: StackFit.expand,
        children: [
          // Title page under the cover while it opens.
          if (open > 0)
            album.pages.isEmpty
                ? const ColoredBox(color: Color(0xFFF7F2E8))
                : BookPageView(
                    album: album,
                    page: album.pages.first,
                    softProof: softProof,
                  ),
          Transform(
            alignment: Alignment.centerLeft,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(-open * math.pi * 0.95),
            child: open > 0.5
                ? const ColoredBox(color: Color(0xFFF1EBDF))
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      coverFront,
                      IgnorePointer(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: frontShade),
                        ),
                      ),
                      if (glint case final g?)
                        IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(-1 + 2.6 * g - 0.8, -1),
                                end: Alignment(-1 + 2.6 * g + 0.2, 1),
                                colors: [
                                  glintColor.withValues(alpha: 0),
                                  glintColor.withValues(alpha: 0.55),
                                  glintColor.withValues(alpha: 0),
                                ],
                                stops: const [0.3, 0.5, 0.7],
                              ),
                            ),
                          ),
                        ),
                      // Hinge groove.
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: w * 0.06,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.25),
                                Colors.white.withValues(alpha: 0.10),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
    final back = face(
      Matrix4.translationValues(0, 0, thick / 2)..rotateY(math.pi),
      w,
      CoverMaterialOverlay(
        finish: material,
        sheen: 0.5,
        child: BookPageView(
          album: album,
          page: album.cover.back,
          softProof: softProof,
        ),
      ),
    );
    final spine = face(
      Matrix4.translationValues(-w / 2, 0, 0)..rotateY(-math.pi / 2),
      thick,
      Stack(
        fit: StackFit.expand,
        children: [
          CoverMaterialOverlay(
            finish: material,
            sheen: 0.3,
            // The drawn spine is thicker than the real one, so stretch the
            // real panel to fit.
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: math.max(album.cover.spineMm, 1) * 4,
                height: f.trimHMm * 4,
                child: BookPageView(
                  album: album,
                  page: album.cover.spine,
                  widthMm: math.max(album.cover.spineMm, 1),
                  softProof: softProof,
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: spineShade),
            ),
          ),
        ],
      ),
    );
    final pageBlock = face(
      Matrix4.translationValues(w / 2, 0, 0)..rotateY(math.pi / 2),
      thick * 0.9,
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE9E1D3), Color(0xFFF7F2E8), Color(0xFFE9E1D3)],
          ),
        ),
      ),
    );

    return Semantics(
      label: semanticLabel,
      image: true,
      child: SizedBox(
        width: w + thick * 2,
        height: h + 30,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              bottom: 0,
              left: w * 0.12,
              right: w * 0.08,
              height: 20,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.26),
                      blurRadius: 22,
                      spreadRadius: -2,
                    ),
                  ],
                ),
              ),
            ),
            if (s < -0.02) spine,
            if (s > 0.02) pageBlock,
            if (c > 0) front else back,
          ],
        ),
      ),
    );
  }
}
