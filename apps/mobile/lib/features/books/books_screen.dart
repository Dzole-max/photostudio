import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/albums/album_repository.dart';
import '../../design/design.dart';
import '../../router/app_router.dart';
import '../home/home_screen.dart';
import '../home/home_sections.dart';
import '../shell/app_shell.dart';

/// The Books tab: every book of yours, as a grid of 3D covers.
class BooksScreen extends ConsumerWidget {
  const BooksScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AlbumSummary summary,
  ) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.homeDeleteBook),
        content: Text(l.homeDeleteBookConfirm(summary.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: MemoriaColors.of(ctx).error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(albumRepositoryProvider).delete(summary.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final albums = ref.watch(albumListProvider);
    ref.listen(albumListProvider, (_, _) => ref.invalidate(albumByIdProvider));
    final books = ownBooks(albums.value ?? const <AlbumSummary>[]);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: TabHeader(
              l.homeYourBooks,
              action: RoundIconButton(
                icon: Icons.add_rounded,
                label: l.homeCreateBook,
                onPressed: () => startCreate(context, ref),
              ),
            ),
          ),
          if (albums.hasValue && books.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: Space.md),
                child: BookShelf(books: []),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(Space.md),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: Space.md,
                  crossAxisSpacing: Space.md,
                  childAspectRatio: 0.74,
                ),
                itemCount: books.length,
                itemBuilder: (context, i) => GestureDetector(
                  onLongPress: () => _delete(context, ref, books[i]),
                  child: MemoriaCard(
                    padding: const EdgeInsets.all(Space.sm),
                    onTap: () => context.push(Routes.albumPreview(books[i].id)),
                    child: ShelfBook(summary: books[i]),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: navClearance(context))),
        ],
      ),
    );
  }
}
