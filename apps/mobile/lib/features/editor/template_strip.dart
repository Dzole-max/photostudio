import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../design/design.dart';
import '../../domain/layout/page_composer.dart';
import '../../domain/layout/templates.dart';
import '../../domain/theme/book_theme.dart';
import '../book/book_page_view.dart';
import 'editor_controller.dart';

/// Layout options for a page, rendered live with its own photos
/// (templates for the page's photo count ±1).
class TemplateStrip extends ConsumerWidget {
  const TemplateStrip({
    required this.albumId,
    required this.pageIndex,
    super.key,
  });

  final String albumId;
  final int pageIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final controller = ref.read(editorControllerProvider(albumId).notifier);
    final state = ref.watch(editorControllerProvider(albumId)).value;
    if (state == null ||
        pageIndex < 0 ||
        pageIndex >= state.album.pages.length) {
      return const SizedBox.shrink();
    }
    final album = state.album;
    final page = album.pages[pageIndex];
    final current = PageTemplate.byId(page.templateId);
    final content = contentOf(page);
    final count = content.photoIds.whereType<String>().length;
    final env = controller.ops.envFor(album);
    final playful = BookTheme.byId(album.themeId).playful;

    final options = <(String, bool)>[];
    if (current.kind == TemplateKind.photo && !current.panorama) {
      for (final tpl in PageTemplate.photoTemplates(playful: playful)) {
        final fits =
            tpl.accepts(count) ||
            tpl.accepts(count - 1) ||
            (tpl.accepts(count + 1) && count > 0);
        if (!fits || tpl.minPhotos > count) continue;
        options.add((tpl.id, false));
        if (const {
          'photo_with_text_right',
          'two_offset',
          'three_one_big_two_small',
          'five_mosaic',
        }.contains(tpl.id)) {
          options.add((tpl.id, true));
        }
      }
    }

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: Radii.sheetTop,
        ),
        padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Row(
                children: [
                  Expanded(child: Text(l.layoutsTitle, style: t.titleSmall)),
                  TextButton.icon(
                    onPressed: () =>
                        controller.apply((ops, a) => ops.addPage(a, pageIndex)),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(l.pageAdd),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: c.error),
                    onPressed:
                        pageIndex == 0 || pageIndex == album.pages.length - 1
                        ? null
                        : () => controller.apply(
                            (ops, a) => ops.removePage(a, pageIndex),
                          ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(l.pageRemove),
                  ),
                ],
              ),
            ),
            if (options.isNotEmpty)
              SizedBox(
                height: 118,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.md,
                    vertical: Space.xs,
                  ),
                  itemCount: options.length,
                  separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                  itemBuilder: (context, i) {
                    final (id, mirrored) = options[i];
                    final candidate = composePage(
                      content.copy()
                        ..templateId = id
                        ..mirrored = mirrored
                        ..userCrops = {},
                      pageIndex,
                      env,
                      id: 'preview_$id',
                    );
                    final selected =
                        id == page.templateId && mirrored == page.mirrored;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label:
                          '${l.layoutsTitle} ${i + 1}${mirrored ? ', ${l.layoutMirror}' : ''}',
                      child: GestureDetector(
                        onTap: () => controller.apply(
                          (ops, a) => ops.swapTemplate(
                            a,
                            pageIndex,
                            id,
                            mirrored: mirrored,
                          ),
                          keepSelection: true,
                        ),
                        child: AnimatedContainer(
                          duration: Motion.short,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selected ? c.primary : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: Radii.inputAll,
                          ),
                          child: ExcludeSemantics(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                boxShadow: Shadows.soft(c),
                              ),
                              child: BookPageView(
                                album: album,
                                page: candidate,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
