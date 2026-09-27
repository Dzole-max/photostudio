import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../app_config.dart';
import '../domain/geo/geo_data.dart';
import '../domain/layout/album_ops.dart';
import '../domain/preflight/preflight_fixes.dart';
import '../domain/pricing/pricing.dart';
import '../domain/text/font_registry.dart';

part 'domain_kit.g.dart';

/// Parsed, bundle-backed data the domain layer needs: font metrics (same
/// files as rendering), Natural Earth outlines and the gazetteer, and the
/// fake-mode print catalogue.
class DomainKit {
  DomainKit({required this.fonts, required this.geo, required this.fakeCatalog})
    : ops = AlbumOps(
        fonts: fonts,
        geo: geo,
        brandMark: AppConfig.brandName.toUpperCase(),
      );

  final FontRegistry fonts;
  final GeoData geo;
  final Catalog fakeCatalog;
  final AlbumOps ops;

  PreflightFixer get fixer => PreflightFixer(ops);

  static Future<DomainKit> load(AssetBundle bundle) async {
    final fontBytes = <String, Uint8List>{};
    await Future.wait([
      for (final face in kFontFaces)
        bundle.load('assets/fonts/${face.file}').then((d) {
          fontBytes[face.file] = d.buffer.asUint8List(
            d.offsetInBytes,
            d.lengthInBytes,
          );
        }),
    ]);
    final strings = await Future.wait([
      bundle.loadString('assets/geo/world.json'),
      bundle.loadString('assets/geo/islands.json'),
      bundle.loadString('assets/geo/places.json'),
      bundle.loadString('assets/spec/catalog.json'),
    ]);
    return DomainKit(
      fonts: FontRegistry(fontBytes),
      geo: GeoData.parse(
        worldJson: strings[0],
        islandsJson: strings[1],
        placesJson: strings[2],
      ),
      fakeCatalog: Catalog.fromJson(strings[3]),
    );
  }
}

@Riverpod(keepAlive: true)
Future<DomainKit> domainKit(Ref ref) => DomainKit.load(rootBundle);
