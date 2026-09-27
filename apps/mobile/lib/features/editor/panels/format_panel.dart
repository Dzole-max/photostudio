import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n.dart';
import '../../../data/domain_kit.dart';
import '../../../design/design.dart';
import '../../../domain/model/album.dart';
import '../../../domain/pricing/pricing.dart';
import '../../../domain/spec/book_format.dart';
import '../../book/material_picker.dart';
import '../editor_controller.dart';

String formatName(AppLocalizations l, String id) => switch (id) {
  'mini_14' => l.formatName_mini_14,
  'landscape_28' => l.formatName_landscape_28,
  'signature_30' => l.formatName_signature_30,
  _ => l.formatName_classic_20,
};

String bindingName(AppLocalizations l, Binding b) => switch (b) {
  Binding.softcover => l.bindingSoftcover,
  Binding.hardcover => l.bindingHardcover,
  Binding.layflat => l.bindingLayflat,
};

String formatSizeLabel(AppLocalizations l, BookFormat f, String locale) {
  final n = NumberFormat.decimalPattern(locale)..maximumFractionDigits = 1;
  return l.formatSize(
    '${n.format(f.trimWMm / 10)} × ${n.format(f.trimHMm / 10)}',
    bindingName(l, f.binding),
  );
}

String money(int cents, String currency, String locale) =>
    NumberFormat.simpleCurrency(
      locale: locale,
      name: currency,
    ).format(cents / 100);

/// Size, cover finish and page count with a live price.
class FormatPanel extends ConsumerWidget {
  const FormatPanel({required this.albumId, super.key});

  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final state = ref.watch(editorControllerProvider(albumId)).value;
    final kit = ref.watch(domainKitProvider).value;
    if (state == null || kit == null) return const SizedBox.shrink();
    final album = state.album;
    final controller = ref.read(editorControllerProvider(albumId).notifier);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final catalog = kit.fakeCatalog;

    return ListView(
      padding: const EdgeInsets.all(Space.md),
      children: [
        for (final f in BookFormat.visible) ...[
          Builder(
            builder: (context) {
              final selected = f.id == album.formatId;
              final pages = f.fitPageCount(album.pages.length);
              final price = priceBook(
                catalog: catalog,
                formatId: f.id,
                innerPages: pages,
                finish: album.coverFinish,
              );
              return MemoriaCard(
                color: selected ? c.surfaceRaised : c.background,
                raised: selected,
                semanticLabel: formatName(l, f.id),
                onTap: selected
                    ? null
                    : () => controller.apply((ops, a) {
                        final laid = ops.relayout(a, formatId: f.id);
                        // Linen and leather-look need a hardcover size.
                        return catalog
                                .product(f.id)
                                .finishes
                                .contains(laid.coverFinish)
                            ? laid
                            : ops.setCoverFinish(laid, CoverFinish.matte);
                      }),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Container(
                            width:
                                40 *
                                (f.aspect >= 1 ? 1 : f.aspect) *
                                (f.trimWMm / 280).clamp(0.6, 1),
                            height:
                                40 /
                                (f.aspect >= 1 ? f.aspect : 1) *
                                (f.trimWMm / 280).clamp(0.6, 1),
                            decoration: BoxDecoration(
                              border: Border.all(color: c.textPrimary),
                              borderRadius: Radii.paperAll,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(formatName(l, f.id), style: t.titleSmall),
                          Text(
                            formatSizeLabel(l, f, locale),
                            style: t.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      l.formatPagesPrice(
                        l.homeBookPages(pages),
                        money(price.bookCents, price.currency, locale),
                      ),
                      style: t.labelMedium,
                    ),
                    if (selected) ...[
                      const SizedBox(width: Space.xs),
                      Icon(Icons.check_circle_rounded, color: c.primary),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: Space.xs),
        ],
        Text(l.formatChangeNote, style: t.bodySmall),
        const SizedBox(height: Space.md),
        Text(l.coverFinish, style: t.labelMedium),
        const SizedBox(height: Space.xs),
        MaterialPicker(
          album: album,
          catalog: catalog,
          onChanged: (f) =>
              controller.apply((ops, a) => ops.setCoverFinish(a, f)),
        ),
      ],
    );
  }
}
