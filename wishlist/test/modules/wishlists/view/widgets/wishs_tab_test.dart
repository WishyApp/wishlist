import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_stats_card.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishs_tab.dart';
import 'package:wishlist/shared/utils/wishlist_illustration_extension.dart';

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
  group('$WishsTab empty state illustration', () {
    final wishlistIllustration = fakeWishlist1.noWishIllustration;

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
