import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../data/samples/sample_books.dart';
import '../../data/services/services.dart';
import '../../design/design.dart';
import '../../router/app_router.dart';
import '../create/creation_controller.dart';

/// Opens an example book in the 3D preview, building it first if needed
/// (a short "Preparing the example book" wait on first use).
Future<void> openExampleBook(
  BuildContext context,
  WidgetRef ref,
  String set,
) async {
  final l = context.l10n;
  final navigator = Navigator.of(context, rootNavigator: true);
  final router = GoRouter.of(context);
  var open = true;
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: Space.md),
              Expanded(child: Text(l.examplePreparing)),
            ],
          ),
        ),
      ),
    ).whenComplete(() => open = false),
  );
  try {
    final id = await ref.read(exampleBookProvider(set).future);
    if (open) navigator.pop();
    await router.push(Routes.albumPreview(id));
  } on Object catch (e, st) {
    if (open) navigator.pop();
    await ref.read(crashReporterProvider).report(e, st);
  }
}

/// Settings → Example books: the two finished books made with our photos,
/// and a way to run the whole flow on them.
class ExampleBooksScreen extends ConsumerWidget {
  const ExampleBooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    Widget tile(String set, String title, IconData icon) => MemoriaCard(
      semanticLabel: title,
      onTap: () => openExampleBook(context, ref, set),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: c.surfaceTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: c.primary),
          ),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(title, style: t.titleMedium)),
          Icon(Icons.chevron_right_rounded, color: c.textSecondary),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsExampleBooks)),
      body: ListView(
        padding: const EdgeInsets.all(Space.md),
        children: [
          Text(l.settingsExampleBooksHint, style: t.bodyMedium),
          const SizedBox(height: Space.md),
          tile('wedding', l.homeSampleWedding, Icons.favorite_outline_rounded),
          const SizedBox(height: Space.sm),
          tile('travel', l.homeSampleTravel, Icons.flight_takeoff_rounded),
          const SizedBox(height: Space.lg),
          SecondaryButton(
            label: l.exampleMakeYourOwn,
            icon: Icons.auto_stories_outlined,
            onPressed: () {
              unawaited(context.push(Routes.importProgress));
              ref
                  .read(creationControllerProvider.notifier)
                  .startSample('travel');
            },
          ),
        ],
      ),
    );
  }
}
