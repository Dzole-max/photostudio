import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';

part 'settings.freezed.dart';
part 'settings.g.dart';

enum AppThemeMode { system, light, dark }

/// The six supported languages with their native names. Native names are the
/// same in every locale by design, so they are data rather than ARB strings.
enum AppLanguage {
  en('English'),
  de('Deutsch'),
  es('Español'),
  fr('Français'),
  it('Italiano'),
  mk('Македонски');

  const AppLanguage(this.nativeName);

  final String nativeName;

  Locale get locale => Locale(name);

  static AppLanguage fromCode(String? code) => AppLanguage.values.firstWhere(
    (l) => l.name == code,
    orElse: () => AppLanguage.en,
  );

  /// Picks the best match for the device locale, falling back to English.
  static AppLanguage fromDevice(Locale device) => fromCode(device.languageCode);
}

@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    required AppLanguage language,
    @Default(AppThemeMode.system) AppThemeMode themeMode,
    @Default(false) bool onboardingDone,
    @Default(false) bool pageTurnSound,
    @Default(true) bool usePhotosForCaptions,
    @Default(false) bool printGuidesSeen,
    @Default(false) bool languageChosen,
    String? displayName,
  }) = _AppSettings;
}

@Riverpod(keepAlive: true)
class SettingsController extends _$SettingsController {
  static const _kLanguage = 'language';
  static const _kLanguageChosen = 'languageChosen';
  static const _kTheme = 'themeMode';
  static const _kOnboarding = 'onboardingDone';
  static const _kSound = 'pageTurnSound';
  static const _kCaptions = 'usePhotosForCaptions';
  static const _kGuides = 'printGuidesSeen';
  static const _kName = 'displayName';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final p = ref.watch(sharedPreferencesProvider);
    final device = PlatformDispatcher.instance.locale;
    final stored = p.getString(_kLanguage);
    return AppSettings(
      language: stored == null
          ? AppLanguage.fromDevice(device)
          : AppLanguage.fromCode(stored),
      languageChosen: p.getBool(_kLanguageChosen) ?? false,
      themeMode: AppThemeMode.values.firstWhere(
        (m) => m.name == p.getString(_kTheme),
        orElse: () => AppThemeMode.system,
      ),
      onboardingDone: p.getBool(_kOnboarding) ?? false,
      pageTurnSound: p.getBool(_kSound) ?? false,
      usePhotosForCaptions: p.getBool(_kCaptions) ?? true,
      printGuidesSeen: p.getBool(_kGuides) ?? false,
      displayName: p.getString(_kName),
    );
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = state.copyWith(language: language, languageChosen: true);
    await _prefs.setString(_kLanguage, language.name);
    await _prefs.setBool(_kLanguageChosen, true);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_kTheme, mode.name);
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(onboardingDone: true);
    await _prefs.setBool(_kOnboarding, true);
  }

  Future<void> setPageTurnSound(bool value) async {
    state = state.copyWith(pageTurnSound: value);
    await _prefs.setBool(_kSound, value);
  }

  Future<void> setUsePhotosForCaptions(bool value) async {
    state = state.copyWith(usePhotosForCaptions: value);
    await _prefs.setBool(_kCaptions, value);
  }

  Future<void> markPrintGuidesSeen() async {
    if (state.printGuidesSeen) return;
    state = state.copyWith(printGuidesSeen: true);
    await _prefs.setBool(_kGuides, true);
  }

  Future<void> setDisplayName(String? name) async {
    final trimmed = name?.trim();
    state = state.copyWith(
      displayName: trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
    if (state.displayName == null) {
      await _prefs.remove(_kName);
    } else {
      await _prefs.setString(_kName, state.displayName!);
    }
  }

  /// Clears everything (used by "delete my data").
  Future<void> reset() async {
    await _prefs.clear();
    ref.invalidateSelf();
  }
}
