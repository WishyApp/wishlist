import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_stats_card.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishs_tab.dart';

import '../../../../fixtures/fake_data.dart';
import '../../../../pump_app.dart';

String _displayedIllustration(WidgetTester tester) {
  final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
  return (picture.bytesLoader as SvgAssetLoader).assetName;
}

Future<void> _pumpEmptyWishsTab(
  WidgetTester tester, {
  required WishlistStatsCardType statCardSelected,
  required bool isWishsBookedHidden,
  required bool isMyWishlist,
}) {
  return tester.pumpApp(
    WishsTab(
      wishlist: fakeWishlist1,
      wishsToDisplay: const IListConst([]),
      shouldDisplayWishs: false,
      statCardSelected: statCardSelected,
      isWishsBookedHidden: isWishsBookedHidden,
      isMyWishlist: isMyWishlist,
      onTapWish: (_, __, {required wishsToDisplay, cardType}) {},
      onAddWish: (_, __) {},
      onFavoriteToggle: (_) {},
      onRefresh: () async {},
    ),
  );
}

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

  group('$WishsTab empty state illustration', () {
    final wishlistIllustration = noWishIllustrationFor(fakeWishlist1.id);

    for (final isMyWishlist in [true, false]) {
      testWidgets(
          'pending tab shows the wishlist illustration '
          '(isMyWishlist: $isMyWishlist)', (tester) async {
        await _pumpEmptyWishsTab(
          tester,
          statCardSelected: WishlistStatsCardType.pending,
          isWishsBookedHidden: false,
          isMyWishlist: isMyWishlist,
        );

        expect(_displayedIllustration(tester), wishlistIllustration);
      });

      testWidgets(
          'booked tab shows the empty booked illustration '
          '(isMyWishlist: $isMyWishlist)', (tester) async {
        await _pumpEmptyWishsTab(
          tester,
          statCardSelected: WishlistStatsCardType.booked,
          isWishsBookedHidden: false,
          isMyWishlist: isMyWishlist,
        );

        expect(_displayedIllustration(tester), Assets.svg.noBookedWish);
      });
    }

    testWidgets(
        'booked tab shows the wishlist illustration when the owner hid '
        'bookings', (tester) async {
      await _pumpEmptyWishsTab(
        tester,
        statCardSelected: WishlistStatsCardType.booked,
        isWishsBookedHidden: true,
        isMyWishlist: true,
      );

      expect(_displayedIllustration(tester), wishlistIllustration);
    });

    testWidgets(
        'pending tab keeps the wishlist illustration when the owner hid '
        'bookings', (tester) async {
      await _pumpEmptyWishsTab(
        tester,
        statCardSelected: WishlistStatsCardType.pending,
        isWishsBookedHidden: true,
        isMyWishlist: true,
      );

      expect(_displayedIllustration(tester), wishlistIllustration);
    });
  });
}
