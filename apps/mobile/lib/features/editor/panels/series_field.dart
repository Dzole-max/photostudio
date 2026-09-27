import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n.dart';
import '../../../data/albums/album_repository.dart';
import '../../../design/design.dart';
import '../../../domain/layout/series_spine.dart';
import '../../../domain/model/album.dart';
import '../editor_controller.dart';

/// "Part of a series": books in one series share a spine design and carry
/// a volume number.
class SeriesField extends ConsumerWidget {
  const SeriesField({required this.album, required this.controller, super.key});

  final Album album;
  final EditorController controller;

  /// Other albums' series and volumes, read from storage.
  Future<Map<String, List<int>>> _existing(WidgetRef ref) async {
    final repo = ref.read(albumRepositoryProvider);
    final out = <String, List<int>>{};
    final summaries = await repo.watchAll().first;
    for (final s in summaries) {
      if (s.id == album.id) continue;
      final a = await repo.load(s.id);
      final name = a?.series;
      if (name == null) continue;
      (out[name] ??= []).add(a!.seriesVolume ?? 1);
    }
    return out;
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final existing = await _existing(ref);
    if (!context.mounted) return;
    final text = TextEditingController(text: album.series);
    final result = await showMemoriaSheet<String>(
      context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Space.lg,
            0,
            Space.lg,
            Space.md + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.seriesTitle, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: Space.xxs),
              Text(l.seriesHint, style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: Space.sm),
              TextField(
                controller: text,
                autofocus: existing.isEmpty,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l.seriesName),
              ),
              if (existing.isNotEmpty) ...[
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: [
                    for (final name in existing.keys)
                      ActionChip(
                        avatar: CircleAvatar(
                          backgroundColor: Color(
                            0xFF000000 |
                                int.parse(
                                  seriesColor(name).substring(1),
                                  radix: 16,
                                ),
                          ),
                        ),
                        label: Text(name),
                        onPressed: () => Navigator.pop(ctx, name),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: Space.md),
              PrimaryButton(
                label: l.commonSave,
                onPressed: () => Navigator.pop(ctx, text.text.trim()),
              ),
              if (album.series != null)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ''),
                  child: Text(l.seriesRemove),
                ),
            ],
          ),
        ),
      ),
    );
    text.dispose();
    if (result == null) return;
    if (result.isEmpty) {
      controller.apply((ops, a) => ops.setSeries(a, null, null));
      return;
    }
    // Keeps its number when the series is unchanged, else joins at the end.
    final volume = result == album.series && album.seriesVolume != null
        ? album.seriesVolume!
        : (existing[result] ?? const <int>[]).fold(0, (m, v) => v > m ? v : m) +
              1;
    controller.apply((ops, a) => ops.setSeries(a, result, volume));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = MemoriaColors.of(context);
    final series = album.series;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 14,
        height: 44,
        decoration: BoxDecoration(
          color: series == null
              ? c.divider
              : Color(
                  0xFF000000 |
                      int.parse(seriesColor(series).substring(1), radix: 16),
                ),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      title: Text(l.seriesTitle),
      subtitle: Text(
        series == null
            ? l.seriesNone
            : l.seriesValue(series, album.seriesVolume ?? 1),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _edit(context, ref),
    );
  }
}
