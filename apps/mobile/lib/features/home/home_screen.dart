import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/albums/album_repository.dart';
import '../../data/samples/sample_books.dart';
import '../../design/design.dart';
import '../../domain/model/album.dart';
import '../../router/app_router.dart';
import '../create/creation_controller.dart';
import '../shell/app_shell.dart';
import 'book_search.dart';
import 'home_hero.dart';
import 'home_sections.dart';

/// The user's own books, newest first (example books live in Settings).
List<AlbumSummary> ownBooks(List<AlbumSummary> all) => [
  for (final b in all)
    if (!kSampleBookIds.containsValue(b.id)) b,
];

/// Starts a new book: the gallery, optionally for a known occasion or with
/// an edition chosen up front.
void startCreate(
  BuildContext context,
  WidgetRef ref, {
  Occasion? occasion,
  Edition? edition,
}) {
  final controller = ref.read(creationControllerProvider.notifier)
    ..startGallery(occasion: occasion);
  if (edition != null) controller.setEdition(edition);
  context.push(Routes.import);
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();
  final _tilt = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(
      () => _tilt.value = (_scroll.offset / 240).clamp(-1.0, 1.0),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    _tilt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final albums = ref.watch(albumListProvider);
    // Covers follow edits made elsewhere.
    ref.listen(albumListProvider, (_, _) => ref.invalidate(albumByIdProvider));
    final books = ownBooks(albums.value ?? const <AlbumSummary>[]);
    final latest = [
      for (final b in books.take(3))
        if (ref.watch(albumByIdProvider(b.id)).value case final a?) a,
    ];

    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.md + 4,
                  Space.sm,
                  Space.md,
                  Space.md,
                ),
                child: Row(
                  children: [
                    const Wordmark(size: 24),
                    const Spacer(),
                    RoundIconButton(
                      icon: Icons.search_rounded,
                      label: l.homeSearch,
                      onPressed: () => showBookSearch(context, books),
                    ),
                    const SizedBox(width: Space.xs),
                    RoundIconButton(
                      icon: Icons.person_outline_rounded,
                      label: l.homeProfile,
                      onPressed: () => context.go(Routes.settings),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: EntryMotion(
              index: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: HomeHero(
                  covers: latest,
                  tilt: _tilt,
                  onCreate: () => startCreate(context, ref),
                  onExplain: () => context.push(Routes.explainer),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: EntryMotion(
              index: 1,
              child: HomeSectionTitle(
                l.homeAboutTitle,
                trailing: l.homeStepOf(1, 4),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: OccasionGrid(firstIndex: 2)),
          SliverToBoxAdapter(
            child: EntryMotion(
              index: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HomeSectionTitle(l.homeWaysTitle),
                  WaysRail(
                    onPick: (e) => startCreate(context, ref, edition: e),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: EntryMotion(
              index: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HomeSectionTitle(l.homeYourBooks),
                  if (albums.hasValue)
                    BookShelf(books: books)
                  else
                    const SizedBox(height: 120),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: navClearance(context) + Space.md),
          ),
        ],
      ),
    );
  }
}
