import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/domain_kit.dart';
import '../../design/design.dart';
import '../../domain/model/album.dart';
import '../../domain/theme/book_theme.dart';
import '../../router/app_router.dart';
import '../book/book_mockup.dart';
import '../home/occasion_labels.dart';
import 'cover_preview.dart';
import 'creation_controller.dart';

String themeName(AppLocalizations l, String id) => switch (id) {
  'wedding_ivory' => l.themeName_wedding_ivory,
  'wedding_blush' => l.themeName_wedding_blush,
  'wedding_midnight' => l.themeName_wedding_midnight,
  'travel_lagoon' => l.themeName_travel_lagoon,
  'travel_terracotta' => l.themeName_travel_terracotta,
  'travel_alpine' => l.themeName_travel_alpine,
  'baby_cloud' => l.themeName_baby_cloud,
  'birthday_confetti' => l.themeName_birthday_confetti,
  'family_heirloom' => l.themeName_family_heirloom,
  _ => l.themeName_minimal_gallery,
};

class OccasionScreen extends ConsumerStatefulWidget {
  const OccasionScreen({super.key});

  @override
  ConsumerState<OccasionScreen> createState() => _OccasionScreenState();
}

class _OccasionScreenState extends ConsumerState<OccasionScreen> {
  final _pages = PageController(viewportFraction: 0.72);
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  String _question(AppLocalizations l, Occasion o, String? place) =>
      switch (o) {
        Occasion.travel =>
          place == null ? l.occasionAskTravel : l.occasionAskTravelPlace(place),
        Occasion.wedding => l.occasionAskWedding,
        Occasion.baby => l.occasionAskBaby,
        Occasion.birthday => l.occasionAskBirthday,
        Occasion.family => l.occasionAskFamily,
        Occasion.other => l.occasionAskOther,
      };

  Future<void> _chooseOther() async {
    final l = context.l10n;
    final picked = await showMemoriaSheet<Occasion>(
      context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              for (final o in Occasion.values)
                MemoriaChip(
                  label: occasionLabel(l, o),
                  icon: occasionIcon(o),
                  selected: o == ref.read(creationControllerProvider).occasion,
                  onSelected: (_) => Navigator.pop(ctx, o),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    ref.read(creationControllerProvider.notifier).confirmOccasion(picked);
    setState(() => _index = 0);
    if (_pages.hasClients) _pages.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final state = ref.watch(creationControllerProvider);
    final kit = ref.watch(domainKitProvider).value;
    final occasion = state.occasion;
    final lang = Localizations.localeOf(context).languageCode;
    if (occasion == null || kit == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final themes = BookTheme.forOccasion(occasion);
    final place = state.suggestion?.destination;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Text(_question(l, occasion, place), style: t.displaySmall),
            ),
            const SizedBox(height: Space.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Text(
                '${l.occasionPickLook} · ${l.occasionLookHint}',
                style: t.bodyMedium,
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: themes.length,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  ref
                      .read(creationControllerProvider.notifier)
                      .setTheme(themes[i].id);
                },
                itemBuilder: (context, i) {
                  final album = previewAlbum(state, kit, themes[i].id, lang);
                  final active = i == _index;
                  return AnimatedScale(
                    duration: Motion.medium,
                    curve: Motion.curve,
                    scale: active ? 1 : 0.88,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: LayoutBuilder(
                            builder: (context, box) => BookMockup(
                              album: album,
                              width: (box.maxWidth * 0.82).clamp(120, 320),
                              yaw: active ? -0.22 : -0.4,
                              semanticLabel: themeName(l, themes[i].id),
                            ),
                          ),
                        ),
                        const SizedBox(height: Space.md),
                        Text(themeName(l, themes[i].id), style: t.titleMedium),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                0,
                Space.lg,
                Space.md,
              ),
              child: Column(
                children: [
                  PrimaryButton(
                    label: l.occasionConfirm,
                    onPressed: () {
                      ref
                          .read(creationControllerProvider.notifier)
                          .confirmOccasion(
                            occasion,
                            themeId: themes[_index].id,
                          );
                      context.push(Routes.createStory(0));
                    },
                  ),
                  TextButton(
                    onPressed: _chooseOther,
                    child: Text(l.occasionSomethingElse),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
