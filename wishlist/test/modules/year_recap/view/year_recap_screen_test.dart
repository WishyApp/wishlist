import 'package:adaptive_test/adaptive_test.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/modules/home/cards/home_card_candidate.dart';
import 'package:wishlist/modules/home/cards/year_recap_provider.dart';
import 'package:wishlist/shared/infra/booked_wishes_realtime_provider.dart';
import 'package:wishlist/modules/year_recap/view/year_recap_screen.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';
import '../../../pump_app.dart';

CompletedWishWithDetails completed() {
  return CompletedWishWithDetails(
    wish: Wish(
      id: 5,
      createdAt: DateTime(2024, 6, 2),
      name: 'Casque',
      description: '',
      quantity: 1,
      wishlistId: 1,
      updatedBy: fakeFriendUserId1,
      updatedAt: fakeUpdatedAt,
    ),
    fromWishlistId: 1,
    fromWishlistName: 'Liste',
    ownerPseudo: 'Alice',
    ownerId: fakeFriendUserId1,
    completedAt: DateTime(2026, 3, 4),
    quantity: 1,
  );
}

void main() {
  Future<void> pumpRecap(
    WidgetTester tester,
    YearRecapFacts facts, {
    WindowConfigData? windowConfig,
  }) async {
    await tester.pumpRouterApp(
      YearRecapRoute(year: 2026).location,
      windowConfig: windowConfig,
      overrides: [
        ...homeScreenOverrides(now: fakeNow),
        yearRecapFactsProvider.overrideWith((ref, year) async => facts),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows every block when the facts are all known', (tester) async {
    await pumpRecap(
      tester,
      YearRecapFacts(
        year: 2026,
        receivedCount: 3,
        offeredCount: 1,
        longestAwaited: completed(),
        mostGiftedFriendPseudo: 'Alice',
      ),
    );

    expect(find.text('Ton année Wishy 2026'), findsOneWidget);
    expect(find.text('3 wishs reçus'), findsOneWidget);
    expect(find.text('1 wish offert'), findsOneWidget);
    expect(
      find.text('Le plus attendu : Casque, sur ta liste depuis 2 juin 2024'),
      findsOneWidget,
    );
    expect(find.text('Ton ami le plus gâté : Alice'), findsOneWidget);
    expect(find.byType(PrimaryButton), findsOneWidget);
    expect(find.text('Retour'), findsWidgets);
  });

  testWidgets('leaves out the blocks without data', (tester) async {
    await pumpRecap(
      tester,
      const YearRecapFacts(year: 2026, receivedCount: 2, offeredCount: 0),
    );

    expect(find.text('2 wishs reçus'), findsOneWidget);
    expect(find.text('0 wish offert'), findsOneWidget);
    expect(find.textContaining('Le plus attendu'), findsNothing);
    expect(find.textContaining('le plus gâté'), findsNothing);
  });

  testWidgets('the back button leaves the page', (tester) async {
    await pumpRecap(
      tester,
      const YearRecapFacts(year: 2026, receivedCount: 2, offeredCount: 0),
    );

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(find.byType(YearRecapScreen), findsNothing);
  });

  testWidgets('computes its facts from the received wishes and bookings',
      (tester) async {
    await tester.pumpRouterApp(
      YearRecapRoute(year: 2026).location,
      overrides: [
        ...homeScreenOverrides(
          now: fakeNow,
          bookedWishes: [
            fakeBookedWish1.copyWith(
              receivedAt: DateTime(2026, 5),
              receivedQuantity: fakeBookedWish1.bookedQuantity,
            ),
          ].toIList(),
        ),
        receivedWishesSnapshotProvider.overrideWith(
          (ref) async => [completed()].toIList(),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('1 wish reçu'), findsOneWidget);
    expect(find.text('1 wish offert'), findsOneWidget);
    expect(
      find.text('Le plus attendu : Casque, sur ta liste depuis 2 juin 2024'),
      findsOneWidget,
    );
  });

  testWidgets('retry also reopens the bookings that failed', (tester) async {
    var loads = 0;
    await tester.pumpRouterApp(
      YearRecapRoute(year: 2026).location,
      overrides: [
        ...homeScreenOverrides(now: fakeNow),
        bookedWishesRealtimeProvider.overrideWith((ref) {
          loads++;
          return loads == 1
              ? Stream.error(Exception('timeout'))
              : Stream.value(const IListConst([]));
        }),
        receivedWishesSnapshotProvider.overrideWith(
          (ref) async => [completed()].toIList(),
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('1 wish reçu'), findsNothing);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text('1 wish reçu'), findsOneWidget);
  });

  testAdaptiveWidgets('$YearRecapScreen golden test', (tester, variant) async {
    await pumpRecap(
      tester,
      YearRecapFacts(
        year: 2026,
        receivedCount: 3,
        offeredCount: 1,
        longestAwaited: completed(),
        mostGiftedFriendPseudo: 'Alice',
      ),
      windowConfig: variant,
    );

    await tester.expectGolden<YearRecapScreen>(variant);
  });
}
