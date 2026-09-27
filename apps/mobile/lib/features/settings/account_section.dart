import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/services.dart';
import '../../design/design.dart';

final _authUserProvider = StreamProvider<AuthUser?>((ref) async* {
  final auth = ref.watch(authServiceProvider);
  yield auth.currentUser;
  yield* auth.changes;
});

class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final user = ref.watch(_authUserProvider).value;
    final email = user?.email;
    if (user == null || user.isAnonymous || email == null) {
      return ListTile(
        leading: const Icon(Icons.person_outline_rounded),
        title: Text(l.settingsSignedOut, style: t.bodyMedium),
      );
    }
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.person_rounded),
          title: Text(l.settingsSignedInAs(email), style: t.bodyMedium),
        ),
        const Divider(indent: Space.md, endIndent: Space.md),
        ListTile(
          leading: const Icon(Icons.logout_rounded),
          title: Text(l.settingsSignOut),
          onTap: () => ref.read(authServiceProvider).signOut(),
        ),
      ],
    );
  }
}
