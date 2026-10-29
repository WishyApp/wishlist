import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/home/view/home_screen.dart';
import 'package:wishlist/shared/infra/wishlist_service.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/navigation/floating_nav_bar_navigator.dart';
import 'package:wishlist/shared/widgets/wishlist_card.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';
import '../../../pump_app.dart';

class _MockWishlistService extends Mock implements WishlistService {}

void main() {
  setUpAll(() => registerFallbackValue(const IListConst<Wishlist>([])));

  testWidgets('$HomeScreen keeps scrolling while a wishlist is dragged',
      (tester) async {
    final (service, pageScrollable) = await _pumpHomeWithTenWishlists(tester);
    expect(pageScrollable.position.pixels, 0);

    // Long press the first card, then drag it to the bottom edge and hold it
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(WishlistCard).first),
    );
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 14; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(pageScrollable.position.pixels, greaterThan(0));

    await gesture.up();
    await tester.pumpAndSettle();

    final saved = verify(() => service.updateWishlistsOrder(captureAny()))
        .captured
        .single as IList<Wishlist>;
    final names = saved.map((wishlist) => wishlist.name).toList();
    expect(names, hasLength(10));
    // Dropped lower than where it started
    expect(names.indexOf('List 0'), greaterThan(0));
    expect(names, containsAll([for (var i = 0; i < 10; i++) 'List $i']));
  });

  testWidgets('$HomeScreen puts the order back and tells when saving fails',
      (tester) async {
    final (service, _) =
        await _pumpHomeWithTenWishlists(tester, failSaving: true);
    final firstCardCenter = tester.getCenter(find.byType(WishlistCard).first);
    expect(find.text('List 0'), findsOneWidget);
    final titleBefore = tester.getCenter(find.text('List 0'));

    // Drop the first wishlist on the second one
    final gesture = await tester.startGesture(firstCardCenter);
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await gesture.up();
    // The drop animation, then the saving fails: the snack bar is still there
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    verify(() => service.updateWishlistsOrder(any())).called(1);
    expect(find.text(AppLocalizationsFr().genericError), findsOneWidget);
    // Back where it was, not left in the order that was not saved
    expect(tester.getCenter(find.text('List 0')), titleBefore);

    // Lets the snack bar go away
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('$HomeScreen scrolls without lifting a card on a quick swipe',
      (tester) async {
    final (service, pageScrollable) = await _pumpHomeWithTenWishlists(tester);

    // No long press: the swipe scrolls the page instead of lifting the card
    await tester.drag(
      find.byType(WishlistCard).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    expect(pageScrollable.position.pixels, greaterThan(0));
    verifyNever(() => service.updateWishlistsOrder(any()));
  });
}

Future<(_MockWishlistService, ScrollableState)> _pumpHomeWithTenWishlists(
  WidgetTester tester, {
  bool failSaving = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 800);
  addTearDown(tester.view.reset);

  final service = _MockWishlistService();
  when(() => service.updateWishlistsOrder(any())).thenAnswer(
    (_) async => failSaving ? throw Exception('offline') : null,
  );
  final wishlists = [
    for (var i = 0; i < 10; i++)
      Wishlist(
        id: 100 + i,
        createdAt: fakeCreatedAt,
        name: 'List $i',
        idOwner: fakeCurrentUserId,
        color: fakeColorBlue,
        canOwnerSeeTakenWish: true,
        order: i,
        updatedBy: fakeCurrentUserId,
        updatedAt: fakeUpdatedAt,
      ),
  ];

  await tester.pumpApp(
    const FloatingNavBarNavigator(
      // ignore: avoid_redundant_argument_values
      currentTab: FloatingNavBarTab.home,
    ),
    overrides: [
      ...homeScreenOverrides(wishlists: wishlists),
      wishlistServiceProvider.overrideWithValue(service),
    ],
  );
  await tester.pumpAndSettle();

  final pageScrollable = tester.state<ScrollableState>(
    find
        .descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  return (service, pageScrollable);
}
