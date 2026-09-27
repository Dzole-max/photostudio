import 'package:material_ui/material_ui.dart';

import '../colors.dart';
import '../tokens.dart';
import 'buttons.dart';

/// Thin calm progress bar with an optional label ("312 of 540").
class CalmProgress extends StatelessWidget {
  const CalmProgress({required this.value, this.label, super.key});

  /// 0..1, or null for indeterminate.
  final double? value;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = MemoriaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: Radii.pillAll,
          child: LinearProgressIndicator(
            value: value,
            minHeight: 4,
            color: c.primary,
            backgroundColor: c.surface,
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: Space.xs),
          Text(
            label!,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Empty state: a tinted icon badge, title, short body, optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.illustration,
    this.icon = Icons.photo_library_outlined,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? illustration;

  @override
  Widget build(BuildContext context) {
    final c = MemoriaColors.of(context);
    final t = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            illustration ??
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: c.surfaceTint,
                    borderRadius: Radii.cardAll,
                  ),
                  child: Icon(icon, size: 32, color: c.primary),
                ),
            const SizedBox(height: Space.lg),
            Text(title, style: t.titleLarge, textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: Space.xs),
              Text(
                body!,
                style: t.bodyMedium?.copyWith(color: c.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Space.lg),
              SecondaryButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Friendly error with a retry action (used by every failing screen).
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.title,
    required this.body,
    required this.retryLabel,
    required this.onRetry,
    super.key,
  });

  final String title;
  final String body;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = MemoriaColors.of(context);
    return EmptyState(
      title: title,
      body: body,
      actionLabel: retryLabel,
      onAction: onRetry,
      illustration: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: c.error.withValues(alpha: 0.12),
          borderRadius: Radii.cardAll,
        ),
        child: Icon(Icons.cloud_off_rounded, size: 32, color: c.error),
      ),
    );
  }
}
