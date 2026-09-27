import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n.dart';
import '../../../design/design.dart';
import '../../book/book_page_view.dart';
import '../editor_controller.dart';

/// All pages in order; press and hold to reorder, tap to jump there.
class PagesPanel extends ConsumerWidget {
  const PagesPanel({
    required this.albumId,
    required this.onGoToPage,
    super.key,
  });

  final String albumId;
  final ValueChanged<int> onGoToPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final state = ref.watch(editorControllerProvider(albumId)).value;
    if (state == null) return const SizedBox.shrink();
    final album = state.album;
    final controller = ref.read(editorControllerProvider(albumId).notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.xs, 0),
          child: Row(
            children: [
              Expanded(child: Text(l.pagesHint, style: t.bodySmall)),
              TextButton.icon(
                onPressed: () => controller.apply(
                  (ops, a) => ops.addPage(a, a.pages.length - 2),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l.pageAdd),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: Space.xs,
            ),
            itemCount: album.pages.length,
            buildDefaultDragHandles: false,
            onReorderStart: (_) => HapticFeedback.lightImpact(),
            onReorderItem: (from, target) {
              HapticFeedback.lightImpact();
              if (target == from) return;
              controller.apply((ops, a) => ops.movePage(a, from, target));
            },
            itemBuilder: (context, i) {
              final page = album.pages[i];
              final fixed = i == 0 || i == album.pages.length - 1;
              final thumb = Padding(
                key: ValueKey(page.id),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: l.editorPage(i + 1),
                        child: GestureDetector(
                          onTap: () => onGoToPage(i),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              boxShadow: Shadows.soft(c),
                            ),
                            child: ExcludeSemantics(
                              child: BookPageView(album: album, page: page),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${i + 1}', style: t.labelSmall),
                  ],
                ),
              );
              return fixed
                  ? thumb
                  : ReorderableDelayedDragStartListener(
                      key: ValueKey(page.id),
                      index: i,
                      child: thumb,
                    );
            },
          ),
        ),
      ],
    );
  }
}
