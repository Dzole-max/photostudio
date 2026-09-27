import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app_config.dart';
import '../../core/l10n.dart';
import '../../data/settings/settings.dart';
import '../../design/design.dart';
import '../../router/app_router.dart';
import '../shell/app_shell.dart';
import 'account_section.dart';
import 'privacy_section.dart';

/// App version for the About section; empty where the platform can't tell.
final _versionProvider = FutureProvider<String>((ref) async {
  try {
    return (await PackageInfo.fromPlatform()).version;
  } on Object {
    return '';
  }
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final notifier = ref.read(settingsControllerProvider.notifier);
    final version = ref.watch(_versionProvider).value ?? '';

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.only(bottom: navClearance(context)),
        children: [
          TabHeader(l.settingsTitle),
          SectionHeader(l.settingsLanguage),
          _Group(
            children: [
              ListTile(
                leading: const Icon(Icons.translate_rounded),
                title: Text(l.settingsLanguage),
                subtitle: Text(settings.language.nativeName),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(Routes.settingsLanguage),
              ),
            ],
          ),
          SectionHeader(l.settingsAppearance),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: SegmentedButton<AppThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: AppThemeMode.system,
                  label: Text(l.themeSystem),
                  icon: const Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment(
                  value: AppThemeMode.light,
                  label: Text(l.themeLight),
                  icon: const Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: AppThemeMode.dark,
                  label: Text(l.themeDark),
                  icon: const Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => notifier.setThemeMode(s.first),
            ),
          ),
          SectionHeader(l.settingsBookSection),
          _Group(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.volume_up_outlined),
                title: Text(l.settingsPageTurnSound),
                value: settings.pageTurnSound,
                onChanged: notifier.setPageTurnSound,
              ),
              const Divider(indent: Space.md, endIndent: Space.md),
              SwitchListTile(
                secondary: const Icon(Icons.edit_note_rounded),
                title: Text(l.settingsUsePhotosForCaptions),
                subtitle: Text(
                  l.settingsUsePhotosForCaptionsHint,
                  style: t.bodySmall,
                ),
                value: settings.usePhotosForCaptions,
                onChanged: notifier.setUsePhotosForCaptions,
              ),
              const Divider(indent: Space.md, endIndent: Space.md),
              ListTile(
                leading: const Icon(Icons.auto_stories_outlined),
                title: Text(l.settingsExampleBooks),
                subtitle: Text(l.settingsExampleBooksHint, style: t.bodySmall),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(Routes.exampleBooks),
              ),
            ],
          ),
          SectionHeader(l.settingsAccount),
          const _Group(children: [AccountSection()]),
          SectionHeader(l.settingsPrivacy),
          const _Group(children: [PrivacySection()]),
          SectionHeader(l.settingsAbout),
          _Group(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text(AppConfig.brandName),
                subtitle: Text(l.settingsVersion(version)),
              ),
              const Divider(indent: Space.md, endIndent: Space.md),
              ListTile(
                leading: const Icon(Icons.public_rounded),
                subtitle: Text(l.settingsNaturalEarth, style: t.bodySmall),
              ),
              ListTile(
                leading: const Icon(Icons.font_download_outlined),
                subtitle: Text(l.settingsFontLicences, style: t.bodySmall),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(l.settingsOpenSourceLicences),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: c.textSecondary,
                ),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: AppConfig.brandName,
                  applicationVersion: version,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: MemoriaCard(
        padding: EdgeInsets.zero,
        child: Column(children: children),
      ),
    );
  }
}
