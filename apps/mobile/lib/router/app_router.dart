import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/settings/settings.dart';
import '../domain/model/album.dart';
import '../features/books/books_screen.dart';
import '../features/check/check_screen.dart';
import '../features/explainer/explainer_screen.dart';
import '../features/occasion/book_kind.dart';
import '../features/occasion/occasion_intro_screen.dart';
import '../features/samples/example_books.dart';
import '../features/create/cover_studio_screen.dart';
import '../features/create/designing_screen.dart';
import '../features/create/edition_screen.dart';
import '../features/create/reveal_screen.dart';
import '../features/create/occasion_screen.dart';
import '../features/create/story_screen.dart';
import '../features/editor/crop_screen.dart';
import '../features/editor/dedication_screen.dart';
import '../features/editor/editor_screen.dart';
import '../features/illustrated/illustrated_screen.dart';
import '../features/memories/memories_screen.dart';
import '../features/home/home_screen.dart';
import '../features/import/import_screen.dart';
import '../features/import/progress_screen.dart';
import '../features/preview/preview_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/settings/language_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';

part 'app_router.g.dart';

abstract final class Routes {
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const books = '/books';
  static const explainer = '/explainer';
  static const exampleBooks = '/settings/examples';
  static String occasion(String kind) => '/occasion/$kind';
  static const orders = '/orders';
  static const settings = '/settings';
  static const settingsLanguage = '/settings/language';
  static const import = '/import';
  static const importProgress = '/import/progress';
  static const createEdition = '/create/edition';
  static const createOccasion = '/create/occasion';
  static const createCover = '/create/cover';
  static const createDesigning = '/create/designing';
  static String createStory(int step) => '/create/story/$step';
  static String album(String id) => '/album/$id';
  static String albumPreview(String id) => '/album/$id/preview';
  static String albumCheck(String id) => '/album/$id/check';
  static String albumCheckout(String id) => '/album/$id/checkout';
  static String albumReveal(String id) => '/album/$id/reveal';
  static String albumDedication(String id) => '/album/$id/dedication';
  static String albumMemories(String id) => '/album/$id/memories';
  static String albumIllustrated(String id) => '/album/$id/illustrated';
  static String albumCrop(String id, int page, int frame) =>
      '/album/$id/crop/$page/$frame';
}

/// Where a freshly designed book opens: the chosen edition's screen on top
/// of the editor (the album is always made, whatever the edition).
String routeAfterDesign(Edition edition, String albumId) => switch (edition) {
  Edition.album => Routes.album(albumId),
  Edition.livingMemories => Routes.albumMemories(albumId),
  Edition.illustrated => Routes.albumIllustrated(albumId),
};

/// Temporary placeholder until the checkout screen is built (Phase 2).
class _CheckoutPlaceholder extends StatelessWidget {
  const _CheckoutPlaceholder();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: const Center(child: Text('Checkout — coming in Phase 2')),
  );
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.home,
    redirect: (context, state) {
      final done = ref.read(settingsControllerProvider).onboardingDone;
      final atOnboarding = state.matchedLocation == Routes.onboarding;
      if (!done && !atOnboarding) return Routes.onboarding;
      if (done && atOnboarding) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.import,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const ImportScreen(),
      ),
      GoRoute(
        path: Routes.importProgress,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const ProgressScreen(),
      ),
      GoRoute(
        path: Routes.createEdition,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const EditionScreen(),
      ),
      GoRoute(
        path: Routes.createOccasion,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const OccasionScreen(),
      ),
      GoRoute(
        path: '/create/story/:step',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => StoryScreen(
          step: int.tryParse(state.pathParameters['step'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: Routes.createCover,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const CoverStudioScreen(),
      ),
      GoRoute(
        path: Routes.createDesigning,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const DesigningScreen(),
      ),
      GoRoute(
        path: '/occasion/:kind',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) {
          final kind =
              BookKind.byName(state.pathParameters['kind']!) ??
              BookKind.wedding;
          return CustomTransitionPage(
            key: state.pageKey,
            transitionDuration: const Duration(milliseconds: 420),
            reverseTransitionDuration: const Duration(milliseconds: 380),
            child: OccasionIntroScreen(kind: kind),
            // The tile grows into the header (Hero); the rest cross-fades.
            transitionsBuilder: (context, animation, _, child) =>
                FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                  child: child,
                ),
          );
        },
      ),
      GoRoute(
        path: Routes.explainer,
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: const ExplainerScreen(),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: '/album/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) =>
            EditorScreen(albumId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'preview',
            builder: (context, state) =>
                PreviewScreen(albumId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'check',
            builder: (context, state) =>
                CheckScreen(albumId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'dedication',
            builder: (context, state) =>
                DedicationScreen(albumId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'reveal',
            pageBuilder: (context, state) => NoTransitionPage(
              child: RevealScreen(albumId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'illustrated',
            builder: (context, state) =>
                IllustratedScreen(albumId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'memories',
            builder: (context, state) =>
                MemoriesScreen(albumId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'checkout',
            builder: (context, state) => const _CheckoutPlaceholder(),
          ),
          GoRoute(
            path: 'crop/:page/:frame',
            builder: (context, state) => CropScreen(
              albumId: state.pathParameters['id']!,
              pageIndex: int.parse(state.pathParameters['page']!),
              frameIndex: int.parse(state.pathParameters['frame']!),
            ),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.books,
                builder: (context, state) => const BooksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.orders,
                builder: (context, state) => const OrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'language',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => const LanguageScreen(),
                  ),
                  GoRoute(
                    path: 'examples',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => const ExampleBooksScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
