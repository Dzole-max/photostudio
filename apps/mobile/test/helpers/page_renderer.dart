import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:memoria/domain/model/album.dart';
import 'package:memoria/domain/spec/book_format.dart';
import 'package:memoria/features/book/book_painter.dart';

import 'domain_fixtures.dart';

/// Decodes every photo of [album] at [size] px (outside fake async).
Future<Map<String, ui.Image>> decodeAlbumImages(
  WidgetTester tester,
  Album album, {
  int size = 400,
}) async {
  final out = <String, ui.Image>{};
  await tester.runAsync(() async {
    for (final p in album.photos.values) {
      final path = p.localAssetId!.replaceFirst('asset:', '');
      final codec = await ui.instantiateImageCodec(
        File(path).readAsBytesSync(),
        targetWidth: p.width >= p.height ? size : null,
        targetHeight: p.width >= p.height ? null : size,
      );
      out[p.id] = (await codec.getNextFrame()).image;
    }
  });
  return out;
}

/// A sheet of pages drawn by the real painter, for golden images.
class PageSheet extends StatelessWidget {
  const PageSheet({
    required this.album,
    required this.pages,
    required this.images,
    this.pageWidth = 260,
    this.columns = 4,
    this.includeBleed = false,
    super.key,
  });

  final Album album;
  final List<BookPage> pages;
  final Map<String, ui.Image> images;
  final double pageWidth;
  final int columns;
  final bool includeBleed;

  @override
  Widget build(BuildContext context) {
    final f = BookFormat.byId(album.formatId);
    final bw = includeBleed ? f.trimWMm + 8 : f.trimWMm;
    final bh = includeBleed ? f.trimHMm + 8 : f.trimHMm;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFFD9D2C5),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final p in pages)
                SizedBox(
                  width: pageWidth,
                  height: pageWidth * bh / bw,
                  child: CustomPaint(
                    painter: BookPagePainter(
                      page: p,
                      trimWMm: f.trimWMm,
                      trimHMm: f.trimHMm,
                      fonts: DomainFixtures.fonts,
                      images: images,
                      includeBleed: includeBleed,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
