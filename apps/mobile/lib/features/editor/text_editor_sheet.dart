import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/services/services.dart';
import '../../design/design.dart';
import '../../domain/layout/type_kit.dart';
import '../../domain/model/album.dart';
import '../create/story_screen.dart';
import 'editor_controller.dart';

Future<void> showTextEditorSheet(
  BuildContext context,
  String albumId,
  EditorTextSelection sel,
) async {
  await showMemoriaSheet<void>(
    context,
    builder: (_) => TextEditorSheet(albumId: albumId, selection: sel),
  );
}

/// Inline text editing: content, size (within theme limits), alignment and
/// an AI rewrite in another tone (section 8.6).
class TextEditorSheet extends ConsumerStatefulWidget {
  const TextEditorSheet({
    required this.albumId,
    required this.selection,
    super.key,
  });

  final String albumId;
  final EditorTextSelection selection;

  @override
  ConsumerState<TextEditorSheet> createState() => _TextEditorSheetState();
}

class _TextEditorSheetState extends ConsumerState<TextEditorSheet> {
  late final TextEditingController _text;
  late TextBlock _original;
  late double _size;
  late TextAlignKind _align;
  bool _rewriting = false;

  @override
  void initState() {
    super.initState();
    final album = ref
        .read(editorControllerProvider(widget.albumId))
        .value!
        .album;
    final page = widget.selection.pageIndex < 0
        ? album.cover.front
        : album.pages[widget.selection.pageIndex];
    _original = page.texts.firstWhere((t) => t.id == widget.selection.textId);
    _text = TextEditingController(text: _original.text);
    _size = _original.sizePt;
    _align = _original.align;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  double get _minSize => _original.minSizePt ?? kMinTextPt;

  double get _maxSize =>
      (_original.sizePt * 1.6).clamp(kMinTextPt + 1, 160).toDouble();

  Future<void> _rewrite(Tone tone) async {
    setState(() => _rewriting = true);
    final album = ref
        .read(editorControllerProvider(widget.albumId))
        .value!
        .album;
    final provider = await ref.read(captionProviderProvider.future);
    final result = await provider.rewrite(_text.text, tone, album.language);
    if (!mounted) return;
    setState(() {
      _text.text = result;
      _rewriting = false;
    });
  }

  void _save() {
    final controller = ref.read(
      editorControllerProvider(widget.albumId).notifier,
    );
    final page = widget.selection.pageIndex;
    final id = widget.selection.textId;
    final text = _text.text.trim();
    if (page < 0) {
      controller.apply((ops, a) {
        final s = a.cover.slots;
        final slots = switch (id) {
          'title' || 'caption' => s.copyWith(title: text),
          'names' => s.copyWith(names: text),
          'date' => s.copyWith(date: text),
          'subtitle' => s.copyWith(subtitle: text),
          'monogram' => s.copyWith(monogram: text),
          'coordinates' => s.copyWith(coordinates: text),
          'stamp_place' => s.copyWith(location: text),
          'age' => s.copyWith(age: text),
          'details' => s.copyWith(details: text),
          _ => s,
        };
        return ops.updateCoverSlots(a, slots);
      });
    } else {
      controller.apply((ops, a) {
        var next = text == _original.text ? a : ops.setText(a, page, id, text);
        if (_size != _original.sizePt || _align != _original.align) {
          next = ops.styleText(next, page, id, sizePt: _size, align: _align);
        }
        return next;
      });
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final isCover = widget.selection.pageIndex < 0;
    final multiline =
        _original.role == TextRole.caption || _original.role == TextRole.body;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.textEdit, style: t.titleMedium),
            const SizedBox(height: Space.sm),
            TextField(
              controller: _text,
              autofocus: true,
              minLines: 1,
              maxLines: multiline ? 5 : 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            if (!isCover) ...[
              const SizedBox(height: Space.md),
              Row(
                children: [
                  Text(l.textSize, style: t.labelMedium),
                  const Spacer(),
                  LabeledIconButton(
                    icon: Icons.remove_rounded,
                    label: l.textSmaller,
                    onPressed: _size - 0.5 >= _minSize
                        ? () => setState(() => _size -= 0.5)
                        : null,
                  ),
                  Text(
                    l.textSizeValue(
                      _size.toStringAsFixed(_size % 1 == 0 ? 0 : 1),
                    ),
                    style: t.labelLarge,
                  ),
                  LabeledIconButton(
                    icon: Icons.add_rounded,
                    label: l.textLarger,
                    onPressed: _size + 0.5 <= _maxSize
                        ? () => setState(() => _size += 0.5)
                        : null,
                  ),
                ],
              ),
              SegmentedButton<TextAlignKind>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: TextAlignKind.left,
                    icon: Tooltip(
                      message: l.textAlignLeft,
                      child: const Icon(Icons.format_align_left_rounded),
                    ),
                  ),
                  ButtonSegment(
                    value: TextAlignKind.center,
                    icon: Tooltip(
                      message: l.textAlignCenter,
                      child: const Icon(Icons.format_align_center_rounded),
                    ),
                  ),
                  ButtonSegment(
                    value: TextAlignKind.right,
                    icon: Tooltip(
                      message: l.textAlignRight,
                      child: const Icon(Icons.format_align_right_rounded),
                    ),
                  ),
                ],
                selected: {_align},
                onSelectionChanged: (s) => setState(() => _align = s.first),
              ),
            ],
            if (multiline || _original.role == TextRole.chapter) ...[
              const SizedBox(height: Space.md),
              Row(
                children: [
                  Icon(Icons.auto_awesome_outlined, size: 18, color: c.accent),
                  const SizedBox(width: Space.xs),
                  Text(l.textRewrite, style: t.labelMedium),
                  const SizedBox(width: Space.xs),
                  Expanded(child: Text(l.textRewriteHint, style: t.bodySmall)),
                  if (_rewriting)
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: Space.xs),
              Wrap(
                spacing: Space.xs,
                children: [
                  for (final tone in Tone.values)
                    MemoriaChip(
                      label: toneLabel(l, tone),
                      selected: false,
                      onSelected: _rewriting ? null : (_) => _rewrite(tone),
                    ),
                ],
              ),
            ],
            const SizedBox(height: Space.lg),
            PrimaryButton(label: l.commonDone, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
