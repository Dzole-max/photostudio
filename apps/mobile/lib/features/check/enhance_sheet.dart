import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/services/services.dart';
import '../../design/design.dart';
import '../../domain/model/album.dart';

/// "Enhance for print": upscales a low-resolution photo, shows a before and
/// after comparison, and returns the enhanced photo if the user keeps it.
Future<PhotoRef?> showEnhanceSheet(BuildContext context, PhotoRef photo) =>
    showMemoriaSheet<PhotoRef>(
      context,
      builder: (ctx) => _EnhanceSheet(photo: photo),
    );

class _EnhanceSheet extends ConsumerStatefulWidget {
  const _EnhanceSheet({required this.photo});

  final PhotoRef photo;

  @override
  ConsumerState<_EnhanceSheet> createState() => _EnhanceSheetState();
}

class _EnhanceSheetState extends ConsumerState<_EnhanceSheet> {
  PhotoRef? _enhanced;
  bool _failed = false;
  double _split = 0.5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      final out = await ref.read(upscaleProviderProvider).enhance(widget.photo);
      if (mounted) setState(() => _enhanced = out);
    } on Object catch (e, st) {
      await ref.read(crashReporterProvider).report(e, st);
      if (mounted) setState(() => _failed = true);
    }
  }

  Widget _image(PhotoRef p) {
    final images = ref.read(photoImagesProvider);
    final asset = p.localAssetId!;
    // Zoomed on the middle, where the difference shows.
    return Transform.scale(
      scale: 2.2,
      child: Image(
        image: images.libraryFor(asset).imageProvider(asset, size: 2048),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.none,
        gaplessPlayback: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final enhanced = _enhanced;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.enhanceTitle, style: t.titleMedium),
            const SizedBox(height: Space.xxs),
            Text(l.enhanceBody, style: t.bodySmall),
            const SizedBox(height: Space.sm),
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: Radii.cardAll,
                child: enhanced == null
                    ? Center(
                        child: _failed
                            ? Text(l.enhanceFailed, style: t.bodyMedium)
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: Space.sm),
                                  Text(l.enhanceWorking, style: t.bodyMedium),
                                ],
                              ),
                      )
                    : LayoutBuilder(
                        builder: (context, box) => GestureDetector(
                          onHorizontalDragUpdate: (d) => setState(
                            () => _split = (_split + d.delta.dx / box.maxWidth)
                                .clamp(0.0, 1.0),
                          ),
                          child: Semantics(
                            slider: true,
                            label: '${l.editionBefore} / ${l.editionAfter}',
                            value: '${(_split * 100).round()} %',
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _image(enhanced),
                                ClipRect(
                                  clipper: _LeftClip(_split),
                                  child: _image(widget.photo),
                                ),
                                Positioned(
                                  left: box.maxWidth * _split - 1,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(width: 2, color: c.surface),
                                ),
                                Positioned(
                                  left: Space.xs,
                                  top: Space.xs,
                                  child: StatusPill(
                                    label: l.editionBefore,
                                    color: c.textPrimary,
                                  ),
                                ),
                                Positioned(
                                  right: Space.xs,
                                  top: Space.xs,
                                  child: StatusPill(
                                    label: l.editionAfter,
                                    color: c.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: Space.md),
            PrimaryButton(
              label: l.enhanceUse,
              icon: Icons.auto_fix_high_outlined,
              onPressed: enhanced == null
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context, enhanced);
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _LeftClip extends CustomClipper<Rect> {
  _LeftClip(this.split);

  final double split;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * split, size.height);

  @override
  bool shouldReclip(_LeftClip old) => old.split != split;
}
