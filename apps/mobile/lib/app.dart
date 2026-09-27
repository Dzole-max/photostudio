import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/l10n.dart';
import 'core/providers.dart';
import 'data/settings/settings.dart';
import 'design/design.dart';
import 'router/app_router.dart';

class MemoriaApp extends ConsumerWidget {
  const MemoriaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final router = ref.watch(appRouterProvider);
    final config = ref.watch(appConfigProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildMemoriaTheme(Brightness.light),
      darkTheme: buildMemoriaTheme(Brightness.dark),
      themeMode: switch (settings.themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      locale: settings.language.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      routerConfig: router,
      builder: (context, child) {
        Widget app = child!;
        if (config.isDev) {
          app = Banner(
            message: context.l10n.devBanner,
            location: BannerLocation.topEnd,
            color: MemoriaColors.of(context).accent,
            child: app,
          );
        }
        return app;
      },
    );
  }
}
