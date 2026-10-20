import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/gen/assets.gen.dart';

void main() {
  group('Assets.svg', () {
    for (final asset in Assets.svg.values) {
      testWidgets('$asset is bundled and parsed by flutter_svg',
          (tester) async {
        final pictureInfo = await tester.runAsync(
          () => vg.loadPicture(SvgAssetLoader(asset), null),
        );

        expect(pictureInfo, isNotNull);
        expect(pictureInfo!.size.isEmpty, isFalse);
        // Les illustrations sont carrées : seule la hauteur est imposée.
        expect(pictureInfo.size.width, pictureInfo.size.height);
        pictureInfo.picture.dispose();
      });
    }
  });
}
