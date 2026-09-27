import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/albums/album_repository.dart';
import '../../design/design.dart';
import '../../domain/model/album.dart';
import '../../router/app_router.dart';
import '../book/book_3d.dart';

/// Gold-tone light for weddings, soft white for everything else.
const _goldLight = Color(0xFFF1DDA8);

/// The reveal after "Designing your book…": the closed book slides in, a
/// band of light passes over the cover, and it opens on the title page.
/// 2.4 s, skippable with a tap, then the chosen edition opens.
class RevealScreen extends ConsumerStatefulWidget {
  const RevealScreen({required this.albumId, super.key});

  final String albumId;

  @override
  ConsumerState<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends ConsumerState<RevealScreen>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  Album? _album;
  bool _landed = false;
  bool _opened = false;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_haptics);
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _leave();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final album = await ref.read(albumRepositoryProvider).load(widget.albumId);
    if (!mounted) return;
    if (album == null) return _leave();
    setState(() => _album = album);
    if (Motion.reduced(context)) {
      _c.value = 0.95;
      await Future<void>.delayed(const Duration(milliseconds: 700));
      _leave();
    } else {
      unawaited(_c.forward());
    }
  }

  void _haptics() {
    if (!_landed && _c.value >= 0.3) {
      _landed = true;
      unawaited(HapticFeedback.lightImpact());
    }
    if (!_opened && _c.value >= 0.93) {
      _opened = true;
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    final edition = _album?.flags.edition ?? Edition.album;
    context.go(routeAfterDesign(edition, widget.albumId));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _span(double v, double a, double b) =>
      ((v - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final album = _album;
    return Scaffold(
      body: Semantics(
        button: true,
        label: l.revealSkip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _leave,
          child: SafeArea(
            child: album == null
                ? const SizedBox.expand()
                : AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) {
                      final v = _c.value;
                      final slide = Curves.easeOutCubic.transform(
                        _span(v, 0, 0.3),
                      );
                      final sweep = _span(v, 0.3, 0.58);
                      final open = Curves.easeInOutCubic.transform(
                        _span(v, 0.6, 0.95),
                      );
                      final wedding = album.occasion == Occasion.wedding;
                      return LayoutBuilder(
                        builder: (context, box) {
                          final w = (box.maxWidth * 0.62).clamp(160.0, 320.0);
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Transform.translate(
                                // Slides in; shifts right as it opens so the
                                // open spread stays centred.
                                offset: Offset(
                                  w * 0.5 * open,
                                  (1 - slide) * box.maxHeight * 0.55,
                                ),
                                child: Transform.scale(
                                  scale: 0.86 + 0.14 * slide,
                                  child: Opacity(
                                    opacity: slide,
                                    child: Book3D(
                                      album: album,
                                      width: w,
                                      yaw:
                                          -0.38 * (1 - slide) -
                                          0.14 +
                                          0.14 * open,
                                      pitch: 0.08,
                                      open: open,
                                      glint: sweep > 0 && sweep < 1
                                          ? sweep
                                          : null,
                                      glintColor: wedding
                                          ? _goldLight
                                          : const Color(0xFFFFFFFF),
                                      semanticLabel: album.title,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: Space.lg),
                              Opacity(
                                opacity: _span(v, 0.7, 0.95),
                                child: Text(
                                  l.revealReady,
                                  style: t.headlineSmall,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
