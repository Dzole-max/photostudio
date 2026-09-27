import 'package:flutter_test/flutter_test.dart';
import 'package:memoria/domain/model/album.dart';
import 'package:memoria/router/app_router.dart';

void main() {
  test('every edition opens on top of the album editor', () {
    for (final e in Edition.values) {
      expect(routeAfterDesign(e, 'a1'), startsWith(Routes.album('a1')));
    }
  });

  test('the chosen edition opens its screen after designing', () {
    expect(
      routeAfterDesign(Edition.livingMemories, 'a1'),
      Routes.albumMemories('a1'),
    );
    expect(
      routeAfterDesign(Edition.illustrated, 'a1'),
      Routes.albumIllustrated('a1'),
    );
    expect(routeAfterDesign(Edition.album, 'a1'), Routes.album('a1'));
  });
}
