import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/services/photo_permission.dart';
import '../../data/services/services.dart';
import '../../data/settings/settings.dart';
import '../../design/design.dart';
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
                _HeroPage(onStart: _next),
                _ArrangePage(onNext: _next),
                _PrivacyPage(onNext: _next),
                _LanguagePage(onNext: _next),
                _PermissionPage(onDone: _finish),
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

class _HeroPage extends StatelessWidget {
  const _HeroPage({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    const ink = Color(0xFF1F1B17);
    return Stack(
      fit: StackFit.expand,
      children: [
        const OpeningBookLoop(),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.45, 1],
              colors: [
                const Color(0xFFF7F3EC).withValues(alpha: 0),
                const Color(0xFFF7F3EC),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppMark(size: 36, color: ink),
                const Spacer(),
                Text(
                  l.onboardingHeroTitle,
                  style: t.displayMedium?.copyWith(color: ink),
                ),
                const SizedBox(height: Space.sm),
                Text(
                  l.onboardingHeroBody,
                  style: t.bodyLarge?.copyWith(color: const Color(0xFF6B635A)),
                ),
                const SizedBox(height: Space.xl),
                PrimaryButton(
                  label: l.onboardingGetStarted,
                  onPressed: onStart,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ArrangePage extends StatelessWidget {
  const _ArrangePage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final steps = [
      l.onboardingStepPick,
      l.onboardingStepDesign,
      l.onboardingStepPrint,
    ];
    return _OnboardingPage(
      action: PrimaryButton(label: l.commonContinue, onPressed: onNext),
      children: [
        Text(l.onboardingArrangeTitle, style: t.displayMedium),
        const SizedBox(height: Space.xl),
        for (var i = 0; i < steps.length; i++) ...[
          Row(
            children: [
              StepIllustration(step: i),
              const SizedBox(width: Space.md),
              Expanded(child: Text(steps[i], style: t.titleMedium)),
            ],
          ),
          if (i < steps.length - 1)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 35),
              child: SizedBox(
                height: Space.lg,
                child: VerticalDivider(
                  color: MemoriaColors.of(context).divider,
                  width: 1,
                ),
              ),
            ),
        ],
      ],
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
  const _PermissionPage({required this.onDone});

  final Future<void> Function() onDone;

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
    if (result == PhotoAccess.limited || result == PhotoAccess.denied) {
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
                Text(l.permissionDeniedBody, style: t.bodyMedium),
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
