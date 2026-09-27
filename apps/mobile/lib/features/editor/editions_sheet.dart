import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../design/design.dart';
import '../../domain/model/album.dart';
import '../../router/app_router.dart';
import '../create/edition_screen.dart';

/// "Editions" from the editor: the book is always the base; the video and
/// the illustrated edition are made from it.
Future<void> showEditionsSheet(BuildContext context, String albumId) =>
    showMemoriaSheet<void>(
      context,
      builder: (_) => _EditionsSheet(albumId: albumId),
    );

class _EditionsSheet extends ConsumerWidget {
  const _EditionsSheet({required this.albumId});

  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final editions = availableEditions(ref);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.editionsSheetTitle,
              style: t.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.md),
            for (final e in editions) ...[
              MemoriaCard(
                onTap: e == Edition.album
                    ? () => Navigator.pop(context)
                    : () {
                        Navigator.pop(context);
                        context.push(
                          e == Edition.livingMemories
                              ? Routes.albumMemories(albumId)
                              : Routes.albumIllustrated(albumId),
                        );
                      },
                semanticLabel: editionName(l, e),
                child: Row(
                  children: [
                    Icon(
                      editionIcon(e),
                      color: e == Edition.album ? c.primary : c.textPrimary,
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(editionName(l, e), style: t.titleSmall),
                          Text(
                            e == Edition.album
                                ? l.editionYouAreHere
                                : editionBody(l, e),
                            style: t.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (e != Edition.album)
                      Text(
                        l.editionOpen,
                        style: t.labelMedium?.copyWith(color: c.info),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xs),
            ],
          ],
        ),
      ),
    );
  }
}
