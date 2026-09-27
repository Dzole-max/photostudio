import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/albums/album_repository.dart';
import '../../design/design.dart';
import '../../router/app_router.dart';
import 'home_sections.dart';

/// Search over the user's books by title.
Future<void> showBookSearch(BuildContext context, List<AlbumSummary> books) =>
    showSearch<void>(
      context: context,
      delegate: _BookSearch(books, context.l10n.searchHint),
    );

class _BookSearch extends SearchDelegate<void> {
  _BookSearch(this.books, String hint) : super(searchFieldLabel: hint);

  final List<AlbumSummary> books;

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
        icon: const Icon(Icons.close_rounded),
        onPressed: () => query = '',
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    icon: const Icon(Icons.arrow_back_rounded),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final l = context.l10n;
    final c = MemoriaColors.of(context);
    final q = query.trim().toLowerCase();
    final hits = [
      for (final b in books)
        if (q.isEmpty || b.title.toLowerCase().contains(q)) b,
    ];
    if (hits.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: q.isEmpty ? l.homeShelfEmpty : l.searchNoResults(query.trim()),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(Space.md),
      itemCount: hits.length,
      separatorBuilder: (_, _) => const SizedBox(height: Space.xs),
      itemBuilder: (context, i) => MemoriaCard(
        onTap: () {
          close(context, null);
          context.push(Routes.albumPreview(hits[i].id));
        },
        child: Row(
          children: [
            Icon(Icons.auto_stories_outlined, color: c.primary),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                hits[i].title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            StatusPill(
              label: statusLabel(l, hits[i].status),
              color: statusColor(c, hits[i].status),
            ),
          ],
        ),
      ),
    );
  }
}
