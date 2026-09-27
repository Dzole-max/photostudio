import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/domain_kit.dart';
import '../../design/design.dart';
import '../../domain/cover/cover_studio.dart';
import '../../domain/model/album.dart';
import '../../router/app_router.dart';
import '../book/book_mockup.dart';
import 'cover_preview.dart';
import 'creation_controller.dart';

String variantName(AppLocalizations l, CoverVariant v) => switch (v.kind) {
  CoverVariantKind.photo => l.coverVariantPhoto,
  CoverVariantKind.monogram =>
    v.templateId == 'cover_travel_stamp'
        ? l.coverVariantStamp
        : l.coverVariantMonogram,
  CoverVariantKind.map => l.coverVariantMap,
  CoverVariantKind.illustrated => l.coverVariantIllustrated,
};

/// Cover Studio (after the story interview): cover variants on 3D book
/// mockups, generated in parallel, with editable words.
class CoverStudioScreen extends ConsumerStatefulWidget {
  const CoverStudioScreen({super.key});

  @override
  ConsumerState<CoverStudioScreen> createState() => _CoverStudioScreenState();
}

class _CoverStudioScreenState extends ConsumerState<CoverStudioScreen> {
  final _pages = PageController(viewportFraction: 0.78);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(
        ref.read(creationControllerProvider.notifier).prepareCoverStudio(),
      ),
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _editWords(CoverSlots slots, Occasion occasion) async {
    final l = context.l10n;
    final fields = <String, TextEditingController>{
      'title': TextEditingController(text: slots.title),
      if (occasion == Occasion.wedding)
        'names': TextEditingController(text: slots.names),
      'date': TextEditingController(text: slots.date),
      'location': TextEditingController(text: slots.location),
    };
    final labels = {
      'title': l.coverTitle,
      'names': l.coverNames,
      'date': l.coverDate,
      'location': l.coverPlace,
    };
    final saved = await showMemoriaSheet<bool>(
      context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.coverEditWords,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: Space.sm),
              for (final e in fields.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.xs),
                  child: TextField(
                    controller: e.value,
                    decoration: InputDecoration(labelText: labels[e.key]),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              const SizedBox(height: Space.sm),
              PrimaryButton(
                label: l.commonDone,
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      ),
    );
    String? v(String k) {
      final t = fields[k]?.text.trim();
      return t == null || t.isEmpty ? null : t;
    }

    if (saved == true) {
      final names = v('names');
      ref
          .read(creationControllerProvider.notifier)
          .updateCoverSlots(
            slots.copyWith(
              title: v('title') ?? slots.title,
              names: names ?? slots.names,
              date: v('date'),
              location: v('location'),
              monogram: names == null
                  ? slots.monogram
                  : _monogram(names) ?? slots.monogram,
            ),
          );
    }
    for (final c in fields.values) {
      c.dispose();
    }
  }

  String? _monogram(String names) {
    final parts = names
        .split(RegExp(r'\s*[&+]\s*|\s+(?:and|und|y|et|e|и)\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (parts.length < 2) return null;
    return '${parts[0].trim()[0].toUpperCase()} & ${parts[1].trim()[0].toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final state = ref.watch(creationControllerProvider);
    final kit = ref.watch(domainKitProvider).value;
    final slots = state.coverSlots;
    final variants = state.coverVariants;
    final lang = Localizations.localeOf(context).languageCode;
    if (kit == null || slots == null || variants.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final controller = ref.read(creationControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Semantics(
                header: true,
                child: Text(l.coverStudioTitle, style: t.displaySmall),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.xs,
                Space.lg,
                0,
              ),
              child: Text(l.coverStudioIntro, style: t.bodyMedium),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: variants.length,
                onPageChanged: controller.selectCover,
                itemBuilder: (context, i) {
                  final v = variants[i];
                  final active = i == state.coverIndex;
                  final painting =
                      v.kind == CoverVariantKind.illustrated &&
                      v.artwork == null;
                  final album = variantAlbum(state, kit, v, slots, lang);
                  return Semantics(
                    label: l.coverVariantOf(
                      i + 1,
                      variants.length,
                      variantName(l, v),
                    ),
                    child: AnimatedScale(
                      duration: Motion.medium,
                      curve: Motion.curve,
                      scale: active ? 1 : 0.88,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: LayoutBuilder(
                              builder: (context, box) => Stack(
                                alignment: Alignment.center,
                                children: [
                                  AnimatedOpacity(
                                    duration: Motion.long,
                                    opacity: painting ? 0.35 : 1,
                                    child: BookMockup(
                                      album: album,
                                      width: (box.maxWidth * 0.78).clamp(
                                        120,
                                        300,
                                      ),
                                      yaw: active ? -0.22 : -0.42,
                                    ),
                                  ),
                                  if (painting)
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const CircularProgressIndicator(),
                                        const SizedBox(height: Space.sm),
                                        Text(
                                          l.coverPainting,
                                          style: t.bodyMedium,
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.sm),
                          Text(variantName(l, v), style: t.titleMedium),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < variants.length; i++)
                  AnimatedContainer(
                    duration: Motion.short,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == state.coverIndex ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == state.coverIndex ? c.textPrimary : c.divider,
                      borderRadius: Radii.pillAll,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.sm,
                Space.lg,
                Space.md,
              ),
              child: Column(
                children: [
                  SecondaryButton(
                    label: l.coverEditWords,
                    icon: Icons.edit_outlined,
                    onPressed: () =>
                        _editWords(slots, state.occasion ?? Occasion.other),
                  ),
                  const SizedBox(height: Space.xs),
                  PrimaryButton(
                    label: l.storyDesign,
                    icon: Icons.auto_stories_outlined,
                    onPressed:
                        state.chosenCover?.kind ==
                                CoverVariantKind.illustrated &&
                            state.chosenCover?.artwork == null
                        ? null
                        : () => context.push(Routes.createDesigning),
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
