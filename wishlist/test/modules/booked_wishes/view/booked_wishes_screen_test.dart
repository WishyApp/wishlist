import 'package:adaptive_test/adaptive_test.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/booked_wishes/view/booked_wishes_screen.dart';
import 'package:wishlist/modules/booked_wishes/view/widgets/user_group_header.dart';
import 'package:wishlist/shared/models/booked_wish_with_details/booked_wish_with_details.dart';
import 'package:wishlist/shared/navigation/floating_nav_bar_navigator.dart';
import 'package:wishlist/shared/widgets/measure_size.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';
import '../../../pump_app.dart';

void main() {
  final l10n = AppLocalizationsFr();
  final bookedWishes =
      [fakeBookedWish1, fakeBookedWish2, fakeBookedWishGiven].toIList();

  Future<void> pumpBookedWishes(
    WidgetTester tester, {
    IList<BookedWishWithDetails>? wishes,
    WindowConfigData? variant,
  }) async {
    await tester.pumpApp(
      const FloatingNavBarNavigator(
        currentTab: FloatingNavBarTab.bookedWishes,
      ),
      windowConfig: variant,
      overrides: homeScreenOverrides(bookedWishes: wishes ?? bookedWishes),
    );
    // Pump suffisamment pour que les animations se terminent
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  Future<void> openGivenTab(WidgetTester tester) async {
    await tester.tap(find.text(l10n.bookedWishesTabGiven));
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  testAdaptiveWidgets('$BookedWishesScreen golden test',
      (tester, variant) async {
    await pumpBookedWishes(tester, variant: variant);

    await tester.expectGolden<BookedWishesScreen>(variant);
  });

  testAdaptiveWidgets('$BookedWishesScreen given tab', (tester, variant) async {
    await pumpBookedWishes(tester, variant: variant);
    await openGivenTab(tester);

    await tester.expectGolden<BookedWishesScreen>(variant, suffix: 'given');
  });

  testAdaptiveWidgets('$BookedWishesScreen when there are no booked wishes',
      (tester, variant) async {
    await tester.pumpApp(
      const FloatingNavBarNavigator(
        currentTab: FloatingNavBarTab.bookedWishes,
      ),
      windowConfig: variant,
      overrides: emptyDataOverrides(),
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<BookedWishesScreen>(variant, suffix: 'empty');
  });

  testWidgets('$BookedWishesScreen shows the wishes left to give first',
      (tester) async {
    await pumpBookedWishes(tester);

    expect(find.text(fakeBookedWish1.wish.name), findsOneWidget);
    expect(find.text(fakeBookedWish2.wish.name), findsOneWidget);
    expect(find.text(fakeBookedWishGiven.wish.name), findsNothing);
    // Stats of the tab only: 1199 + 279
    expect(
      find.textContaining(
        l10n.bookedWishesToGiveCount(2),
        findRichText: true,
      ),
      findsWidgets,
    );
    expect(find.textContaining('1478', findRichText: true), findsWidgets);
  });

  testWidgets('$BookedWishesScreen lists the given wishes in their tab',
      (tester) async {
    await pumpBookedWishes(tester);
    await openGivenTab(tester);

    expect(find.text(fakeBookedWishGiven.wish.name), findsOneWidget);
    expect(find.text(fakeBookedWish1.wish.name), findsNothing);
    expect(find.text(fakeBookedWish2.wish.name), findsNothing);
    expect(
      find.textContaining(l10n.bookedWishesGivenCount(1), findRichText: true),
      findsWidgets,
    );
    expect(find.textContaining('1478', findRichText: true), findsNothing);
    // The date of receipt replaces the wishlist name
    expect(find.textContaining('Reçu le'), findsOneWidget);
    expect(find.text(fakeBookedWishGiven.wishlistName), findsNothing);
  });

  testWidgets('$BookedWishesScreen keeps a partly received wish to give',
      (tester) async {
    // Someone else booked it too: the item received may be theirs
    final partlyReceived = fakeBookedWishGiven.copyWith(
      wish: fakeBookedWishGiven.wish.copyWith(
        quantity: 2,
        takenByUser: [
          ...fakeBookedWishGiven.wish.takenByUser,
          fakeWishTakenByUser.copyWith(wishId: 4),
        ].toIList(),
      ),
    );
    await pumpBookedWishes(tester, wishes: [partlyReceived].toIList());

    expect(find.text(partlyReceived.wish.name), findsOneWidget);

    await openGivenTab(tester);

    expect(find.text(partlyReceived.wish.name), findsNothing);
    expect(find.text(l10n.bookedWishesNothingGiven), findsOneWidget);
  });

  testWidgets('$BookedWishesScreen says when everything was given',
      (tester) async {
    await pumpBookedWishes(tester, wishes: [fakeBookedWishGiven].toIList());

    expect(find.text(l10n.bookedWishesNothingToGive), findsOneWidget);
    expect(find.text(fakeBookedWishGiven.wish.name), findsNothing);
  });

  testWidgets(
      '$BookedWishesScreen keeps the first group below the header with '
      'a larger text', (tester) async {
    // The header grows taller than with the default text scale
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpBookedWishes(tester);

    final header = find.descendant(
      of: find.byType(BookedWishesScreen),
      matching: find.byType(MeasureSize),
    );
    final headerBottom = tester.getBottomLeft(header).dy;
    final firstGroupTop =
        tester.getTopLeft(find.byType(UserGroupHeader).first).dy;
    expect(firstGroupTop, greaterThanOrEqualTo(headerBottom));
  });

  testWidgets('$BookedWishesScreen searches within the current tab',
      (tester) async {
    await pumpBookedWishes(tester);

    await tester.enterText(find.byType(TextField), 'kindle');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text(l10n.wishlistNoWishBooked), findsOneWidget);

    await openGivenTab(tester);

    expect(find.text(fakeBookedWishGiven.wish.name), findsOneWidget);
  });
}
