@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/page_renderer.dart';
import '../helpers/sample_books.dart';

void main() {
  for (final (set, lang) in [
    ('wedding', 'en'),
    ('travel', 'en'),
    ('travel', 'mk'),
  ]) {
    testWidgets('sample $set book ($lang)', (tester) async {
      final album = buildSampleBook(set, language: lang);
      final images = await decodeAlbumImages(tester, album);
      final pages = [album.cover.front, ...album.pages.take(15)];
      tester.view.physicalSize = const Size(1160 * 1.0, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        PageSheet(album: album, pages: pages, images: images, pageWidth: 272),
      );
      await expectLater(
        find.byType(PageSheet),
        matchesGoldenFile('goldens/book_${set}_${lang}_a.png'),
      );
      await tester.pumpWidget(
        PageSheet(
          album: album,
          pages: album.pages.skip(15).toList(),
          images: images,
          pageWidth: 272,
        ),
      );
      await expectLater(
        find.byType(PageSheet),
        matchesGoldenFile('goldens/book_${set}_${lang}_b.png'),
      );
    });
  }
}
