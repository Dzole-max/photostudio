@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:memoria/domain/illustration/comic.dart';
import 'package:memoria/domain/illustration/illustrated_edition.dart';
import 'package:memoria/domain/model/album.dart';

import '../domain/illustrated_edition_test.dart' show illustrate;
import '../helpers/page_renderer.dart';
import '../helpers/sample_books.dart';

void main() {
  for (final set in ['wedding', 'travel']) {
    testWidgets('comic pages ($set)', (tester) async {
      final ill = illustrate(
        buildSampleBook(set),
        IllustrationStyle.comic,
        IllustrationScope.wholeBook,
      );
      final images = await decodeAlbumImages(tester, ill);
      final pages = ill.pages
          .where((p) => kComicTemplates.contains(p.templateId))
          .take(8)
          .toList();
      tester.view.physicalSize = const Size(1160, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        PageSheet(album: ill, pages: pages, images: images, pageWidth: 272),
      );
      await expectLater(
        find.byType(PageSheet),
        matchesGoldenFile('goldens/comic_$set.png'),
      );
    });
  }
}
