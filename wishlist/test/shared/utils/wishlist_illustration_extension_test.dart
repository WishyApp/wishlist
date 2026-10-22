import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/shared/utils/wishlist_illustration_extension.dart';

import '../../fixtures/fake_data.dart';

void main() {
  group('noWishIllustrationFor', () {
    test('returns the same illustration for the same wishlist', () {
      for (final id in [0, 1, 2, 42, 123456]) {
        expect(noWishIllustrationFor(id), noWishIllustrationFor(id));
      }
    });

    test('maps ids 0, 1 and 2 to the three distinct illustrations', () {
      expect(noWishIllustrationFor(0), Assets.svg.noWishBag);
      expect(noWishIllustrationFor(1), Assets.svg.noWishFlashlight);
      expect(noWishIllustrationFor(2), Assets.svg.noWishBoxHat);
    });

    test('cycles every three ids', () {
      expect(noWishIllustrationFor(3), noWishIllustrationFor(0));
      expect(noWishIllustrationFor(4), noWishIllustrationFor(1));
      expect(noWishIllustrationFor(5), noWishIllustrationFor(2));
    });

    test('is safe with negative and very large ids', () {
      final allowed = {
        Assets.svg.noWishBag,
        Assets.svg.noWishFlashlight,
        Assets.svg.noWishBoxHat,
      };
      for (final id in [-1, -2, -3, -1000001, 9007199254740991]) {
        expect(allowed, contains(noWishIllustrationFor(id)));
      }
    });
  });

  test('noWishIllustration follows the wishlist id', () {
    expect(
      fakeWishlist2.noWishIllustration,
      noWishIllustrationFor(fakeWishlist2.id),
    );
  });
}
