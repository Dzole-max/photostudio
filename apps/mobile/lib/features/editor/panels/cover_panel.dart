import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n.dart';
import '../../../data/settings/settings.dart';
import '../../../design/design.dart';
import '../../../domain/layout/cover_composer.dart';
import '../../../domain/model/album.dart';
import '../../book/book_page_view.dart';
import '../editor_controller.dart';
import 'series_field.dart';

/// Cover templates (rendered live) and the cover's text fields, plus the
/// book language.
class CoverPanel extends ConsumerStatefulWidget {
  const CoverPanel({required this.albumId, super.key});

  final String albumId;

  @override
  ConsumerState<CoverPanel> createState() => _CoverPanelState();
}

class _CoverPanelState extends ConsumerState<CoverPanel> {
  final Map<String, TextEditingController> _fields = {};

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _field(String key, String? value) =>
      _fields.putIfAbsent(key, () => TextEditingController(text: value ?? ''));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final state = ref.watch(editorControllerProvider(widget.albumId)).value;
    if (state == null) return const SizedBox.shrink();
    final album = state.album;
    final controller = ref.read(
      editorControllerProvider(widget.albumId).notifier,
    );
    final env = controller.ops.envFor(album);
    final slots = album.cover.slots;
    final templates = CoverTemplate.all.where((x) => !x.stub).toList();

    String? v(String key) {
      final text = _fields[key]?.text.trim();
      return text == null || text.isEmpty ? null : text;
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      children: [
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            itemCount: templates.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
            itemBuilder: (context, i) {
              final id = templates[i].id;
              final selected = id == album.cover.templateId;
              final preview = composeCover(
                templateId: id,
                slots: slots,
                env: env,
                spineMm: album.cover.spineMm,
              ).front;
              return Semantics(
                button: true,
                selected: selected,
                label: '${l.coverDesign} ${i + 1}',
                child: GestureDetector(
                  onTap: selected
                      ? null
                      : () => controller.apply(
                          (ops, a) => ops.changeCoverTemplate(a, id),
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
                      child: BookPageView(album: album, page: preview),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (key, label, value) in [
                ('title', l.coverTitle, slots.title),
                ('subtitle', l.coverSubtitle, slots.subtitle),
                ('names', l.coverNames, slots.names),
                ('date', l.coverDate, slots.date),
                ('location', l.coverPlace, slots.location),
                if (album.occasion == Occasion.wedding)
                  ('monogram', l.coverMonogram, slots.monogram),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.xs),
                  child: TextField(
                    controller: _field(key, value),
                    decoration: InputDecoration(
                      labelText: label,
                      isDense: true,
                    ),
                  ),
                ),
              SecondaryButton(
                label: l.coverApply,
                onPressed: () => controller.apply(
                  (ops, a) => ops.updateCoverSlots(
                    a,
                    a.cover.slots.copyWith(
                      title: v('title') ?? a.title,
                      subtitle: v('subtitle'),
                      names: v('names'),
                      date: v('date'),
                      location: v('location'),
                      monogram: v('monogram') ?? a.cover.slots.monogram,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.md),
              Text(l.bookLanguage, style: t.labelMedium),
              Text(l.bookLanguageHint, style: t.bodySmall),
              const SizedBox(height: Space.xs),
              DropdownButtonFormField<AppLanguage>(
                initialValue: AppLanguage.fromCode(album.language),
                items: [
                  for (final lang in AppLanguage.values)
                    DropdownMenuItem(value: lang, child: Text(lang.nativeName)),
                ],
                onChanged: (lang) {
                  if (lang == null || lang.name == album.language) return;
                  controller.apply(
                    (ops, a) => ops.relayout(a, language: lang.name),
                  );
                },
              ),
              const SizedBox(height: Space.sm),
              SeriesField(album: album, controller: controller),
              const SizedBox(height: Space.md),
            ],
          ),
        ),
      ],
    );
  }
}
