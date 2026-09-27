import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n.dart';
import '../../data/services/services.dart';
import '../../data/settings/settings.dart';
import '../../design/design.dart';
import '../../router/app_router.dart';

class PrivacySection extends ConsumerWidget {
  const PrivacySection({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final subject = context.l10n.settingsExportData;
    final json = await ref.read(userDataServiceProvider).exportJson();
    await SharePlus.instance.share(ShareParams(text: json, subject: subject));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final c = MemoriaColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.settingsDeleteConfirmTitle),
        content: Text(l.settingsDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: c.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(userDataServiceProvider).deleteEverything();
    await ref.read(authServiceProvider).signOut();
    await ref.read(settingsControllerProvider.notifier).reset();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.settingsDeleteDone)));
    context.go(Routes.onboarding);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.shield_outlined),
          subtitle: Text(l.settingsPrivacyNote, style: t.bodySmall),
        ),
        const Divider(indent: Space.md, endIndent: Space.md),
        ListTile(
          leading: const Icon(Icons.download_rounded),
          title: Text(l.settingsExportData),
          onTap: () => _export(context, ref),
        ),
        const Divider(indent: Space.md, endIndent: Space.md),
        ListTile(
          leading: Icon(Icons.delete_outline_rounded, color: c.error),
          title: Text(
            l.settingsDeleteData,
            style: t.bodyLarge?.copyWith(color: c.error),
          ),
          onTap: () => _delete(context, ref),
        ),
      ],
    );
  }
}
