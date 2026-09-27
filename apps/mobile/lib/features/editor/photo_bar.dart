import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/services/services.dart';
import '../../design/design.dart';
import '../../domain/layout/album_ops.dart';
import '../../domain/layout/smart_crop.dart';
import '../../domain/preflight/preflight.dart';
import '../../router/app_router.dart';
import 'editor_controller.dart';

/// Contextual actions for a tapped photo (section 8.6).
class PhotoBar extends ConsumerWidget {
  const PhotoBar({required this.albumId, required this.selection, super.key});

  final String albumId;
  final FrameSelection selection;

  Future<void> _replace(BuildContext context, WidgetRef ref) async {
    final state = ref.read(editorControllerProvider(albumId)).value;
    if (state == null) return;
    final picked = await pickPhoto(context, ref, state);
    if (picked == null) return;
    ref
        .read(editorControllerProvider(albumId).notifier)
        .apply(
          (ops, a) => ops.setPhoto(
            a,
            selection.pageIndex,
            selection.frameIndex,
            picked,
          ),
        );
  }

  Future<void> _caption(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final state = ref.read(editorControllerProvider(albumId)).value;
    if (state == null) return;
    final page = state.album.pages[selection.pageIndex];
    final existing =
        page.texts
            .where((t) => t.id == 'cap_${selection.frameIndex}')
            .firstOrNull
            ?.text ??
        '';
    final controller = TextEditingController(text: existing);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.photoCaption),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 90,
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    ref
        .read(editorControllerProvider(albumId).notifier)
        .apply(
          (ops, a) => ops.setCaption(
            a,
            selection.pageIndex,
            selection.frameIndex,
            result,
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final controller = ref.read(editorControllerProvider(albumId).notifier);
    final state = ref.watch(editorControllerProvider(albumId)).value;
    if (state == null || selection.pageIndex < 0) {
      return const SizedBox.shrink();
    }
    final album = state.album;
    final frame = album.pages[selection.pageIndex].frames[selection.frameIndex];
    final photo = frame.photoId == null ? null : album.photos[frame.photoId];
    final inner = frame.borderMm > 0
        ? frame.rectMm.deflate(frame.borderMm)
        : frame.rectMm;
    final dpi = photo == null ? null : effectiveDpi(photo, frame.crop, inner);

    Widget action(
      IconData icon,
      String label,
      VoidCallback? onTap, {
      Color? color,
    }) => Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.inputAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kMinTapTarget + 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color ?? c.textPrimary),
                const SizedBox(height: 4),
                ExcludeSemantics(
                  child: Text(
                    label,
                    style: t.labelSmall?.copyWith(
                      color: color ?? c.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: Radii.sheetTop,
        ),
        padding: const EdgeInsets.fromLTRB(
          Space.xs,
          Space.sm,
          Space.xs,
          Space.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dpi != null && dpi < kWarnDpi)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.sm,
                  0,
                  Space.sm,
                  Space.xs,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: dpi < kBlockDpi ? c.error : c.warning,
                      size: 18,
                    ),
                    const SizedBox(width: Space.xs),
                    Expanded(
                      child: Text(
                        '${l.photoLowDpi} (${l.cropDpi(dpi.round())})',
                        style: t.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                action(
                  Icons.swap_vert_rounded,
                  l.photoReplace,
                  () => _replace(context, ref),
                ),
                action(
                  Icons.crop_rounded,
                  l.photoCrop,
                  photo == null
                      ? null
                      : () => context.push(
                          Routes.albumCrop(
                            albumId,
                            selection.pageIndex,
                            selection.frameIndex,
                          ),
                        ),
                ),
                action(
                  Icons.swap_horiz_rounded,
                  l.photoSwap,
                  () => controller.startSwap(selection),
                ),
                action(
                  Icons.short_text_rounded,
                  l.photoCaption,
                  () => _caption(context, ref),
                ),
                action(Icons.open_in_full_rounded, l.photoMakeHero, () {
                  controller.apply(
                    (ops, a) => ops.makeHero(
                      a,
                      selection.pageIndex,
                      selection.frameIndex,
                    ),
                  );
                }),
                action(Icons.delete_outline_rounded, l.photoRemove, () {
                  controller.apply(
                    (ops, a) => ops.removePhoto(
                      a,
                      selection.pageIndex,
                      selection.frameIndex,
                    ),
                  );
                }, color: c.error),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing unused photos; returns the chosen photo id.
Future<String?> pickPhoto(
  BuildContext context,
  WidgetRef ref,
  EditorState state,
) {
  final l = context.l10n;
  final unused = AlbumOps.unused(state.album);
  final images = ref.read(photoImagesProvider);
  return showMemoriaSheet<String>(
    context,
    expand: true,
    builder: (ctx) => Column(
      children: [
        Text(l.photoReplaceTitle, style: Theme.of(ctx).textTheme.titleMedium),
        const SizedBox(height: Space.sm),
        Expanded(
          child: unused.isEmpty
              ? EmptyState(title: l.photoAllUsed)
              : GridView.builder(
                  padding: const EdgeInsets.all(Space.xs),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: Space.xs,
                    crossAxisSpacing: Space.xs,
                  ),
                  itemCount: unused.length,
                  itemBuilder: (_, i) => Semantics(
                    button: true,
                    label: unused[i].placeName ?? l.tabPhotos,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, unused[i].id),
                      child: ClipRRect(
                        borderRadius: Radii.inputAll,
                        child: Image(
                          image: images.provider(unused[i], size: 256),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    ),
  );
}
