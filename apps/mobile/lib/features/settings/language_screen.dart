import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../design/design.dart';
import '../onboarding/onboarding_screen.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsLanguage)),
      body: ListView(
        padding: const EdgeInsets.all(Space.md),
        children: [
          Text(
            l.onboardingLanguageBody,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Space.md),
          const LanguageList(),
        ],
      ),
    );
  }
}
