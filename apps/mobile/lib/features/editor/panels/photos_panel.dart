import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n.dart';
import '../../../data/services/services.dart';
import '../../../design/design.dart';
import '../../../domain/layout/album_ops.dart';
import '../editable_page.dart';
import '../editor_controller.dart';

/// Tray of photos not yet in the book: drag onto a frame, or tap to add on
/// a page of its own after the current spread.
class PhotosPanel extends ConsumerWidget {
  const PhotosPanel({
    required this.albumId,
    required this.currentSpread,
    super.key,
  });

  final String albumId;
  final int currentSpread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final state = ref.watch(editorControllerProvider(albumId)).value;
    if (state == null) return const SizedBox.shrink();
    final unused = AlbumOps.unused(state.album);
    final images = ref.watch(photoImagesProvider);
    final controller = ref.read(editorControllerProvider(albumId).notifier);
    if (unused.isEmpty) {
      return Center(child: Text(l.photoAllUsed, style: t.bodyMedium));
    }
    // Insert after the right page of the spread in view (spread 0 = cover).
    final after = currentSpread <= 1 ? 0 : (currentSpread - 1) * 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, 0),
          child: Text(l.photoTrayHint, style: t.bodySmall),
        ),
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(Space.md),
            itemCount: unused.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.xs),
            itemBuilder: (context, i) {
              final p = unused[i];
              final tile = AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: Radii.inputAll,
                  child: Image(
                    image: images.provider(p, size: 256),
                    fit: BoxFit.cover,
                  ),
                ),
              );
              return Semantics(
                button: true,
                label: [
                  p.placeName,
                  if (p.faces.isNotEmpty) l.photoPeople(p.faces.length),
                ].whereType<String>().join(', '),
                child: LongPressDraggable<EditorDrag>(
                  data: PhotoDrag(p.id),
                  hapticFeedbackOnStart: true,
                  feedback: SizedBox(
                    width: 90,
                    height: 90,
                    child: DecoratedBox(
                      decoration: BoxDecoration(boxShadow: Shadows.raised(c)),
                      child: tile,
                    ),
                  ),
                  childWhenDragging: Opacity(opacity: 0.3, child: tile),
                  child: GestureDetector(
                    onTap: () => controller.apply(
                      (ops, a) => ops.addPage(
                        a,
                        after.clamp(0, a.pages.length - 2),
                        photoId: p.id,
                      ),
                    ),
                    child: tile,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
