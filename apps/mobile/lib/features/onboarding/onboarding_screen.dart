import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/services/photo_permission.dart';
import '../../data/services/services.dart';
import '../../data/settings/settings.dart';
import '../../design/design.dart';
import '../../domain/model/album.dart';
import '../create/creation_controller.dart';
import '../create/edition_screen.dart';
import '../home/home_hero.dart';
import '../samples/example_books.dart';
import '../../router/app_router.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageCount = 5;
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= _pageCount - 1) return;
    _controller.nextPage(
      duration: Motion.reduced(context) ? Duration.zero : Motion.medium,
      curve: Motion.curve,
    );
  }

  Future<void> _finish() async {
    await ref.read(settingsControllerProvider.notifier).completeOnboarding();
    if (mounted) context.go(Routes.home);
  }

  /// "See an example book": finish onboarding and open the Zanzibar book.
  Future<void> _example() async {
    await _finish();
    if (!mounted) return;
    await openExampleBook(context, ref, 'travel');
  }

  /// No photo access: go straight into a sample book.
  Future<void> _trySample() async {
    await _finish();
    if (!mounted) return;
    unawaited(context.push(Routes.importProgress));
    await ref.read(creationControllerProvider.notifier).startSample('travel');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (p) => setState(() => _page = p),
              children: [
                _HeroPage(onStart: _next, onExample: _example),
                _EditionsPage(onNext: _next),
                _PrivacyPage(onNext: _next),
                _LanguagePage(onNext: _next),
                _PermissionPage(onDone: _finish, onTrySample: _trySample),
              ],
            ),
          ),
          if (_page > 0)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: Semantics(
                  label: l.onboardingPageIndicator(_page + 1, _pageCount),
                  child: ExcludeSemantics(
                    child: _Dots(count: _pageCount, index: _page),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = MemoriaColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: Motion.short,
            curve: Motion.curve,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? c.textPrimary : c.divider,
              borderRadius: Radii.pillAll,
            ),
          ),
      ],
    );
  }
}

/// Shared layout for the text pages: content scrolls, CTA pinned at bottom.
class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.children, required this.action});

  final List<Widget> children;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: Space.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
            const SizedBox(height: Space.md),
            action,
            const SizedBox(height: Space.md),
          ],
        ),
      ),
    );
  }
}

class _HeroPage extends ConsumerWidget {
  const _HeroPage({required this.onStart, required this.onExample});

  final VoidCallback onStart;
  final VoidCallback onExample;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.heroFrom, c.heroTo],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Wordmark(size: 26, onDark: true),
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: ExcludeSemantics(
                    child: CoverFan(covers: const [], tilt: _still),
                  ),
                ),
              ),
              Text(
                l.onboardingHeroTitle,
                style: t.displayMedium?.copyWith(color: c.textOnDark),
              ),
              const SizedBox(height: Space.sm),
              Text(
                l.onboardingHeroBody,
                style: t.bodyLarge?.copyWith(color: c.textOnDarkBody),
              ),
              const SizedBox(height: Space.xl),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.primaryOnDark,
                  foregroundColor: c.onPrimaryOnDark,
                  minimumSize: const Size.fromHeight(54),
                ),
                onPressed: onStart,
                child: Text(l.onboardingGetStarted),
              ),
              const SizedBox(height: Space.xs),
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: c.textOnDark),
                  onPressed: onExample,
                  icon: const Icon(Icons.auto_stories_outlined),
                  label: Text(l.onboardingSeeExample),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final ValueNotifier<double> _still = ValueNotifier(0);

/// Sample photos for the edition tiles (bundled; no permission needed).
PhotoRef _sample(String id, int w, int h, {int faces = 0}) => PhotoRef(
  id: id,
  localAssetId: 'asset:assets/samples/travel/$id.jpg',
  width: w,
  height: h,
  faces: [
    for (var i = 0; i < faces; i++)
      FaceBox(x: 0.25 + i * 0.3, y: 0.3, w: 0.2, h: 0.2),
  ],
);

/// Screen 2: the three editions, each as a small moving picture.
class _EditionsPage extends StatelessWidget {
  const _EditionsPage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final tiles = [
      (l.editionAlbumName, l.editionAlbumBody, const _CoverOpenTile()),
      (
        l.editionVideoName,
        l.editionVideoBody,
        MemoriesPreview(
          photos: [
            _sample('t05', 3000, 2000),
            _sample('t06', 3000, 2000, faces: 2),
            _sample('t09', 3000, 2000),
          ],
        ),
      ),
      (
        l.editionCartoonName,
        l.editionCartoonBody,
        CartoonPreview(photo: _sample('t06', 3000, 2000, faces: 2)),
      ),
    ];
    return _OnboardingPage(
      action: PrimaryButton(label: l.commonContinue, onPressed: onNext),
      children: [
        Text(l.onboardingEditionsTitle, style: t.displaySmall),
        const SizedBox(height: Space.xs),
        Text(l.onboardingEditionsBody, style: t.bodyMedium),
        const SizedBox(height: Space.md),
        for (var i = 0; i < tiles.length; i++)
          _StaggerIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: MemoriaCard(
                padding: EdgeInsets.zero,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(Radii.card),
                      ),
                      child: SizedBox(
                        width: 128,
                        height: 104,
                        child: ExcludeSemantics(child: tiles[i].$3),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: Space.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tiles[i].$1, style: t.titleSmall),
                            const SizedBox(height: Space.xxs),
                            Text(
                              tiles[i].$2,
                              style: t.bodySmall,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Tiles arrive one after another.
class _StaggerIn extends StatefulWidget {
  const _StaggerIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: 120 + widget.index * 140), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final v = Curves.easeOutCubic.transform(_c.value);
      return Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - v)),
          child: child,
        ),
      );
    },
  );
}

/// A small book whose photo cover keeps opening onto its title page.
class _CoverOpenTile extends ConsumerStatefulWidget {
  const _CoverOpenTile();

  @override
  ConsumerState<_CoverOpenTile> createState() => _CoverOpenTileState();
}

class _CoverOpenTileState extends ConsumerState<_CoverOpenTile>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MemoriaColors.of(context);
    final images = ref.watch(photoImagesProvider);
    final cover = _sample('t05', 3000, 2000);
    return ColoredBox(
      color: c.surface,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // Hold closed, open, hold open, close.
          final v = _c.value;
          final open = v < 0.3
              ? 0.0
              : v < 0.5
              ? Curves.easeInOut.transform((v - 0.3) / 0.2)
              : v < 0.8
              ? 1.0
              : 1 - Curves.easeInOut.transform((v - 0.8) / 0.2);
          const w = 62.0, h = 46.0;
          return Center(
            child: Transform.translate(
              offset: Offset(w / 2 * open - w / 2 + 6, 0),
              child: SizedBox(
                width: w * 2,
                height: h,
                child: Stack(
                  children: [
                    // Title page under the cover.
                    Positioned(
                      left: w,
                      top: 0,
                      width: w,
                      height: h,
                      child: Container(
                        color: const Color(0xFFF7F2E8),
                        alignment: Alignment.center,
                        child: Text(
                          'Zanzibar',
                          style: TextStyle(
                            fontFamily: Fonts.cormorant,
                            fontSize: 9,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: w,
                      top: 0,
                      width: w,
                      height: h,
                      child: Transform(
                        alignment: Alignment.centerLeft,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.004)
                          ..rotateY(-open * 3.1),
                        child: open > 0.5
                            ? const ColoredBox(color: Color(0xFFEFE7DA))
                            : DecoratedBox(
                                decoration: BoxDecoration(
                                  boxShadow: Shadows.soft(c),
                                ),
                                child: Image(
                                  image: images.provider(cover, size: 256),
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PrivacyPage extends ConsumerWidget {
  const _PrivacyPage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final settings = ref.watch(settingsControllerProvider);
    return _OnboardingPage(
      action: PrimaryButton(label: l.commonContinue, onPressed: onNext),
      children: [
        Icon(Icons.lock_outline_rounded, size: 40, color: c.secondary),
        const SizedBox(height: Space.lg),
        Text(l.onboardingPrivacyTitle, style: t.displayMedium),
        const SizedBox(height: Space.md),
        Text(l.onboardingPrivacyBody, style: t.bodyLarge),
        const SizedBox(height: Space.sm),
        Text(
          l.onboardingPrivacyTraining,
          style: t.bodyMedium?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: Space.xl),
        MemoriaCard(
          padding: EdgeInsets.zero,
          child: SwitchListTile(
            value: settings.usePhotosForCaptions,
            onChanged: (v) => ref
                .read(settingsControllerProvider.notifier)
                .setUsePhotosForCaptions(v),
            title: Text(l.settingsUsePhotosForCaptions, style: t.titleSmall),
            subtitle: Text(
              l.settingsUsePhotosForCaptionsHint,
              style: t.bodySmall,
            ),
          ),
        ),
      ],
    );
  }
}

class _LanguagePage extends ConsumerWidget {
  const _LanguagePage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return _OnboardingPage(
      action: PrimaryButton(label: l.commonContinue, onPressed: onNext),
      children: [
        Text(l.onboardingLanguageTitle, style: t.displayMedium),
        const SizedBox(height: Space.xs),
        Text(l.onboardingLanguageBody, style: t.bodyMedium),
        const SizedBox(height: Space.lg),
        const LanguageList(),
      ],
    );
  }
}

class _PermissionPage extends ConsumerStatefulWidget {
  const _PermissionPage({required this.onDone, required this.onTrySample});

  final Future<void> Function() onDone;
  final Future<void> Function() onTrySample;

  @override
  ConsumerState<_PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends ConsumerState<_PermissionPage> {
  PhotoAccess? _result;
  bool _busy = false;

  Future<void> _request() async {
    setState(() => _busy = true);
    final access = await ref.read(photoPermissionProvider).request();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = access;
    });
    if (access == PhotoAccess.granted) await widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final permission = ref.read(photoPermissionProvider);
    final result = _result;

    final Widget action;
    if (result == PhotoAccess.denied) {
      // Without photos, the sample book is the way in.
      action = Column(
        children: [
          PrimaryButton(
            label: l.homeTrySample,
            icon: Icons.auto_stories_outlined,
            onPressed: widget.onTrySample,
          ),
          const SizedBox(height: Space.xs),
          TextButton(onPressed: widget.onDone, child: Text(l.commonContinue)),
        ],
      );
    } else if (result == PhotoAccess.limited) {
      action = PrimaryButton(label: l.commonContinue, onPressed: widget.onDone);
    } else {
      action = Column(
        children: [
          PrimaryButton(
            label: l.permissionAllow,
            onPressed: _request,
            busy: _busy,
          ),
          const SizedBox(height: Space.xs),
          TextButton(onPressed: widget.onDone, child: Text(l.permissionLater)),
        ],
      );
    }

    return _OnboardingPage(
      action: action,
      children: [
        Icon(Icons.photo_library_outlined, size: 40, color: c.textPrimary),
        const SizedBox(height: Space.lg),
        Text(l.permissionTitle, style: t.displayMedium),
        const SizedBox(height: Space.md),
        Text(l.permissionBody, style: t.bodyLarge),
        if (result == PhotoAccess.limited) ...[
          const SizedBox(height: Space.lg),
          MemoriaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.permissionLimitedBody, style: t.bodyMedium),
                const SizedBox(height: Space.sm),
                SecondaryButton(
                  label: l.permissionSelectMore,
                  icon: Icons.add_photo_alternate_outlined,
                  onPressed: permission.selectMore,
                  expand: false,
                ),
              ],
            ),
          ),
        ],
        if (result == PhotoAccess.denied) ...[
          const SizedBox(height: Space.lg),
          MemoriaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.permissionSampleBody, style: t.bodyMedium),
                const SizedBox(height: Space.sm),
                SecondaryButton(
                  label: l.permissionOpenSettings,
                  onPressed: permission.openSystemSettings,
                  expand: false,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Radio list of the six languages by native name; switches instantly.
class LanguageList extends ConsumerWidget {
  const LanguageList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(
      settingsControllerProvider.select((s) => s.language),
    );
    final c = MemoriaColors.of(context);
    return MemoriaCard(
      padding: EdgeInsets.zero,
      child: RadioGroup<AppLanguage>(
        groupValue: current,
        onChanged: (lang) {
          if (lang != null) {
            ref.read(settingsControllerProvider.notifier).setLanguage(lang);
          }
        },
        child: Column(
          children: [
            for (final lang in AppLanguage.values) ...[
              RadioListTile<AppLanguage>(
                value: lang,
                title: Text(
                  lang.nativeName,
                  style: Theme.of(context).textTheme.bodyLarge,
                  locale: lang.locale,
                ),
                activeColor: c.textPrimary,
                controlAffinity: ListTileControlAffinity.trailing,
              ),
              if (lang != AppLanguage.values.last)
                const Divider(indent: Space.md, endIndent: Space.md),
            ],
          ],
        ),
      ),
    );
  }
}
