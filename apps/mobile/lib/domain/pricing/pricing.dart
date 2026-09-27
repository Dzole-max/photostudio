import 'dart:convert';

import '../model/album.dart';

/// Money is handled in integer cents end to end.
int toCents(num value) => (value * 100).round();

class CatalogProduct {
  const CatalogProduct({
    required this.formatId,
    required this.productUid,
    required this.basePriceCents,
    required this.basePages,
    required this.perPageCents,
    required this.finishSurchargeCents,
  });

  final String formatId;
  final String productUid;
  final int basePriceCents;
  final int basePages;
  final int perPageCents;

  /// Only finishes the product can be made with (cloth needs a hardcover).
  final Map<CoverFinish, int> finishSurchargeCents;

  List<CoverFinish> get finishes => finishSurchargeCents.keys.toList();
}

class ShippingOption {
  const ShippingOption({
    required this.id,
    required this.region,
    required this.priceCents,
    required this.minDays,
    required this.maxDays,
  });

  final String id;
  final String region;
  final int priceCents;
  final int minDays;
  final int maxDays;
}

/// Print catalogue: fetched from the provider at runtime (cached 24 h); the
/// fake mode reads packages/layout_spec/fixtures/catalog.json.
class Catalog {
  const Catalog({
    required this.currency,
    required this.products,
    required this.shipping,
    required this.euCountries,
    required this.supportedCountries,
  });

  factory Catalog.fromJson(String source) {
    final j = jsonDecode(source) as Map<String, Object?>;
    return Catalog(
      currency: j['currency']! as String,
      products: [
        for (final p in j['products']! as List<Object?>)
          if (p case {
            'formatId': final String formatId,
            'productUid': final String uid,
            'basePrice': final num base,
            'basePages': final int basePages,
            'perPage': final num perPage,
            'coverFinishSurcharge': final Map<String, Object?> finish,
          })
            CatalogProduct(
              formatId: formatId,
              productUid: uid,
              basePriceCents: toCents(base),
              basePages: basePages,
              perPageCents: toCents(perPage),
              finishSurchargeCents: {
                for (final f in CoverFinish.values)
                  if (finish[f.name] case final num v) f: toCents(v),
              },
            ),
      ],
      shipping: [
        for (final s in j['shipping']! as List<Object?>)
          if (s case {
            'id': final String id,
            'region': final String region,
            'price': final num price,
            'minDays': final int minDays,
            'maxDays': final int maxDays,
          })
            ShippingOption(
              id: id,
              region: region,
              priceCents: toCents(price),
              minDays: minDays,
              maxDays: maxDays,
            ),
      ],
      euCountries: (j['euCountries']! as List<Object?>).cast<String>().toSet(),
      supportedCountries: (j['supportedCountries']! as List<Object?>)
          .cast<String>(),
    );
  }

  final String currency;
  final List<CatalogProduct> products;
  final List<ShippingOption> shipping;
  final Set<String> euCountries;
  final List<String> supportedCountries;

  CatalogProduct product(String formatId) => products.firstWhere(
    (p) => p.formatId == formatId,
    orElse: () => throw ArgumentError('no product for $formatId'),
  );

  /// Shipping options for a destination country (EU or rest of world).
  List<ShippingOption> shippingFor(String countryCode) {
    final region = euCountries.contains(countryCode) ? 'EU' : 'WORLD';
    return shipping.where((s) => s.region == region).toList();
  }
}

class PriceBreakdown {
  const PriceBreakdown({
    required this.baseCents,
    required this.extraPages,
    required this.extraPagesCents,
    required this.finishCents,
    required this.extraCopies,
    required this.extraCopiesCents,
    required this.shippingCents,
    required this.currency,
  });

  factory PriceBreakdown.fromJson(Map<String, Object?> j) => PriceBreakdown(
    baseCents: j['baseCents']! as int,
    extraPages: j['extraPages']! as int,
    extraPagesCents: j['extraPagesCents']! as int,
    finishCents: j['finishCents']! as int,
    extraCopies: j['extraCopies']! as int,
    extraCopiesCents: j['extraCopiesCents']! as int,
    shippingCents: j['shippingCents']! as int,
    currency: j['currency']! as String,
  );

  final int baseCents;
  final int extraPages;
  final int extraPagesCents;
  final int finishCents;
  final int extraCopies;
  final int extraCopiesCents;
  final int shippingCents;
  final String currency;

  int get bookCents => baseCents + extraPagesCents + finishCents;

  int get subtotalCents => bookCents + extraCopiesCents;

  int get totalCents => subtotalCents + shippingCents;

  Map<String, Object> toJson() => {
    'baseCents': baseCents,
    'extraPages': extraPages,
    'extraPagesCents': extraPagesCents,
    'finishCents': finishCents,
    'extraCopies': extraCopies,
    'extraCopiesCents': extraCopiesCents,
    'shippingCents': shippingCents,
    'totalCents': totalCents,
    'currency': currency,
  };
}

/// Extra copies cost 75 % of the format base price (section 7.8).
const double kExtraCopyFactor = 0.75;

/// `price = formatBase + max(0, innerPages − basePages) × perPage
///        + coverFinishSurcharge + (copies − 1) × formatBase × 0.75 + shipping`
PriceBreakdown priceBook({
  required Catalog catalog,
  required String formatId,
  required int innerPages,
  required CoverFinish finish,
  int copies = 1,
  ShippingOption? shipping,
}) {
  if (copies < 1) throw ArgumentError.value(copies, 'copies', 'must be ≥ 1');
  final p = catalog.product(formatId);
  final extraPages = innerPages > p.basePages ? innerPages - p.basePages : 0;
  final extraCopies = copies - 1;
  return PriceBreakdown(
    baseCents: p.basePriceCents,
    extraPages: extraPages,
    extraPagesCents: extraPages * p.perPageCents,
    finishCents: p.finishSurchargeCents[finish] ?? 0,
    extraCopies: extraCopies,
    extraCopiesCents: (extraCopies * p.basePriceCents * kExtraCopyFactor)
        .round(),
    shippingCents: shipping?.priceCents ?? 0,
    currency: catalog.currency,
  );
}
