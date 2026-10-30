import 'dart:io';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/home/cards/home_card_candidate.dart';
import 'package:wishlist/modules/home/cards/home_cards_provider.dart';
import 'package:wishlist/modules/home/view/home_screen.dart';
import 'package:wishlist/modules/home/view/widgets/cards/home_card_view.dart';
import 'package:wishlist/modules/home/view/widgets/home_profile_header.dart';
import 'package:wishlist/modules/home/view/widgets/home_received_wishes_row.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/received_wishes_summary_provider.dart';
import 'package:wishlist/shared/infra/repositories/user/user_streams_providers.dart';
import 'package:wishlist/shared/infra/wishlists_realtime_provider.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/models/received_wishes_summary/received_wishes_summary.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/navigation/floating_nav_bar_navigator.dart';
import 'package:wishlist/shared/page_layout_empty/page_layout_empty.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';
import '../../../pump_app.dart';

final _friendAcceptedCard = HomeCardCandidate(
  type: 'friend_accepted',
  stateKey: 'friend_accepted:a',
  content: FriendAccepted(fakeFriendAppUser1, fakeNow),
);

const _photoCard = HomeCardCandidate(
  type: 'onboarding',
  stateKey: 'onboarding:photo',
  content: Onboarding(OnboardingStep.photo),
);

final _completedWish = CompletedWishWithDetails(
  wish: fakeWish1,
  fromWishlistId: fakeWishlist1.id,
  fromWishlistName: fakeWishlist1.name,
  ownerPseudo: fakeFriendProfile1.pseudo,
  ownerId: fakeFriendUserId1,
  completedAt: fakeNow,
  quantity: 1,
);

void main() {
  testAdaptiveWidgets('$HomeScreen golden test', (tester, variant) async {
    await tester.pumpApp(
      // We pump FloatingNavBarNavigator instead of HomeScreen directly
      // to have the same layout as in the app with the floating navigation bar
      const FloatingNavBarNavigator(
        // ignore: avoid_redundant_argument_values
        currentTab: FloatingNavBarTab.home,
      ),
      windowConfig: variant,
      overrides: homeScreenOverrides(),
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<HomeScreen>(variant);
  });

  testAdaptiveWidgets('$HomeScreen with cards golden test',
      (tester, variant) async {
    await tester.pumpApp(
      const FloatingNavBarNavigator(
        // ignore: avoid_redundant_argument_values
        currentTab: FloatingNavBarTab.home,
      ),
      windowConfig: variant,
      overrides: homeScreenOverrides(
        now: fakeNow,
        homeCards: [_friendAcceptedCard, _photoCard],
      ),
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<HomeScreen>(variant, suffix: 'with_cards');
  });

  testAdaptiveWidgets('$HomeScreen when empty', (tester, variant) async {
    await tester.pumpApp(
      const FloatingNavBarNavigator(
        // ignore: avoid_redundant_argument_values
        currentTab: FloatingNavBarTab.home,
      ),
      windowConfig: variant,
      overrides: homeScreenOverrides(wishlists: []),
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<HomeScreen>(variant, suffix: 'empty');
  });

  testAdaptiveWidgets('$HomeScreen when loading fails',
      (tester, variant) async {
    await tester.pumpApp(
      const FloatingNavBarNavigator(
        // ignore: avoid_redundant_argument_values
        currentTab: FloatingNavBarTab.home,
      ),
      windowConfig: variant,
      overrides: [
        ...homeScreenOverrides(),
        wishlistsRealtimeProvider.overrideWith(
          (ref) => Stream.error(
            AppException(
              statusCode: 500,
              cause: const SocketException('Failed host lookup'),
            ),
          ),
        ),
      ],
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<HomeScreen>(variant, suffix: 'error');
  });

  testWidgets('$HomeScreen shows the header above the wishlists',
      (tester) async {
    await tester.pumpApp(
      const FloatingNavBarNavigator(
        // ignore: avoid_redundant_argument_values
        currentTab: FloatingNavBarTab.home,
      ),
      overrides: homeScreenOverrides(),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeProfileHeader), findsOneWidget);
    expect(find.text('MonPseudo'), findsOneWidget);
    expect(find.text('Mes wishlists'), findsOneWidget);
    expect(find.text(fakeWishlists.first.name), findsWidgets);
    expect(find.text('Pas encore de wishlist'), findsNothing);
  });

  testWidgets(
      '$HomeScreen puts the cards between the header and the received '
      'wishes', (tester) async {
    await tester.pumpApp(
      const FloatingNavBarNavigator(
        // ignore: avoid_redundant_argument_values
        currentTab: FloatingNavBarTab.home,
      ),
      overrides: homeScreenOverrides(
        now: fakeNow,
        homeCards: [_friendAcceptedCard],
        completedWishes: [_completedWish],
      ),
    );
    await tester.pumpAndSettle();

    final header = tester.getBottomLeft(find.byType(HomeProfileHeader)).dy;
    final card = tester.getTopLeft(find.byType(HomeCardView)).dy;
    final cardBottom = tester.getBottomLeft(find.byType(HomeCardView)).dy;
    final row = tester.getTopLeft(find.byType(HomeReceivedWishesRow)).dy;
    expect(card, greaterThanOrEqualTo(header));
    expect(row, greaterThanOrEqualTo(cardBottom));
  });

  testWidgets('$HomeScreen shows no card without any', (tester) async {
    await tester.pumpApp(
      const FloatingNavBarNavigator(
        // ignore: avoid_redundant_argument_values
        currentTab: FloatingNavBarTab.home,
      ),
      overrides: homeScreenOverrides(now: fakeNow),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeCardView), findsNothing);
    expect(find.byType(HomeProfileHeader), findsOneWidget);
  });

  testWidgets('$HomeScreen keeps the header without any wishlist',
      (tester) async {
    await tester.pumpApp(
      const FloatingNavBarNavigator(
        // ignore: avoid_redundant_argument_values
        currentTab: FloatingNavBarTab.home,
      ),
      overrides: homeScreenOverrides(wishlists: []),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeProfileHeader), findsOneWidget);
    expect(find.text('Pas encore de wishlist'), findsOneWidget);
    expect(find.byType(PageLayoutEmpty), findsNothing);
  });

  testWidgets('$HomeScreen explains a network error and retries',
      (tester) async {
    final l10n = AppLocalizationsFr();
    var loads = 0;

    await tester.pumpApp(
      const FloatingNavBarNavigator(
        // ignore: avoid_redundant_argument_values
        currentTab: FloatingNavBarTab.home,
      ),
      overrides: [
        ...homeScreenOverrides(),
        wishlistsRealtimeProvider.overrideWith((ref) {
          loads++;
          return loads == 1
              ? Stream.error(
                  AppException(
                    statusCode: 500,
                    cause: const SocketException('Failed host lookup'),
                  ),
                )
              : Stream.value(fakeWishlists);
        }),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.networkErrorTitle), findsOneWidget);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text(l10n.networkErrorTitle), findsNothing);
    expect(find.text(fakeWishlists.first.name), findsWidgets);
  });

  testWidgets(
      '$HomeScreen retry reloads the profile, the received wishes and the '
      'wishlists', (tester) async {
    var profileLoads = 0;
    var summaryLoads = 0;
    var wishlistsLoads = 0;
    final error = AppException(
      statusCode: 500,
      cause: const SocketException('Failed host lookup'),
    );

    await tester.pumpApp(
      const FloatingNavBarNavigator(
        // ignore: avoid_redundant_argument_values
        currentTab: FloatingNavBarTab.home,
      ),
      overrides: [
        ...homeScreenOverrides(),
        watchCurrentUserProfileProvider.overrideWith((ref) {
          profileLoads++;
          return profileLoads == 1
              ? Stream.error(error)
              : Stream.value(fakeCurrentUserProfile);
        }),
        receivedWishesSummaryProvider.overrideWith((ref) {
          summaryLoads++;
          return summaryLoads == 1
              ? Stream.error(error)
              : Stream.value(const ReceivedWishesSummary.empty());
        }),
        wishlistsRealtimeProvider.overrideWith((ref) {
          wishlistsLoads++;
          return wishlistsLoads == 1
              ? Stream.error(error)
              : Stream.value(fakeWishlists);
        }),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(profileLoads, 2);
    expect(summaryLoads, 2);
    expect(wishlistsLoads, 2);
  });

  group('header and received wishes row stay in every state', () {
    final summaryOverride = receivedWishesSummaryProvider.overrideWith(
      (ref) => Stream.value(
        ReceivedWishesSummary(count: 2, latestCompletedAt: fakeNow),
      ),
    );

    Future<void> pumpHome(
      WidgetTester tester,
      Stream<List<Wishlist>> wishlists,
    ) async {
      await tester.pumpApp(
        const FloatingNavBarNavigator(
          // ignore: avoid_redundant_argument_values
          currentTab: FloatingNavBarTab.home,
        ),
        overrides: [
          ...homeScreenOverrides(
            now: fakeNow,
            homeCards: [_friendAcceptedCard],
          ),
          summaryOverride,
          wishlistsRealtimeProvider.overrideWith((ref) => wishlists),
        ],
      );
    }

    testWidgets('while the wishlists load', (tester) async {
      await pumpHome(tester, const Stream.empty());
      await tester.pump(const Duration(milliseconds: 500));
      // The cards resolve after the first frame
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(HomeProfileHeader), findsOneWidget);
      expect(find.text('MonPseudo'), findsOneWidget);
      expect(find.text('2 wishs reçus'), findsOneWidget);
      expect(find.byType(HomeCardView), findsOneWidget);
    });

    testWidgets('when the wishlists fail to load', (tester) async {
      final l10n = AppLocalizationsFr();
      await pumpHome(
        tester,
        Stream.error(
          AppException(
            statusCode: 500,
            cause: const SocketException('Failed host lookup'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.networkErrorTitle), findsOneWidget);
      expect(find.byType(HomeProfileHeader), findsOneWidget);
      expect(find.text('MonPseudo'), findsOneWidget);
      expect(find.text('2 wishs reçus'), findsOneWidget);
      expect(find.byType(HomeCardView), findsOneWidget);
    });
  });

  testWidgets(
      '$HomeScreen pull to refresh reloads the profile and the received '
      'wishes too', (tester) async {
    var profileLoads = 0;
    var summaryLoads = 0;
    await tester.pumpApp(
      const FloatingNavBarNavigator(
        // ignore: avoid_redundant_argument_values
        currentTab: FloatingNavBarTab.home,
      ),
      overrides: [
        ...homeScreenOverrides(now: fakeNow),
        watchCurrentUserProfileProvider.overrideWith((ref) {
          profileLoads++;
          return Stream.value(fakeCurrentUserProfile);
        }),
        receivedWishesSummaryProvider.overrideWith((ref) {
          summaryLoads++;
          return Stream.value(const ReceivedWishesSummary.empty());
        }),
      ],
    );
    await tester.pumpAndSettle();
    expect(profileLoads, 1);
    expect(summaryLoads, 1);

    await tester.fling(
      find.byType(CustomScrollView).first,
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(profileLoads, 2);
    expect(summaryLoads, 2);
  });

  testWidgets('$HomeScreen pull to refresh reloads the cards', (tester) async {
    var cardsLoads = 0;
    await tester.pumpApp(
      const FloatingNavBarNavigator(
        // ignore: avoid_redundant_argument_values
        currentTab: FloatingNavBarTab.home,
      ),
      overrides: [
        ...homeScreenOverrides(now: fakeNow),
        homeCardsProvider.overrideWith((ref) async {
          cardsLoads++;
          return [_friendAcceptedCard];
        }),
      ],
    );
    await tester.pumpAndSettle();
    expect(cardsLoads, 1);

    await tester.fling(
      find.byType(CustomScrollView).first,
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(cardsLoads, 2);
    expect(find.byType(HomeCardView), findsOneWidget);
  });

  testWidgets(
      '$HomeScreen pull to refresh does not throw when the wishlists fail',
      (tester) async {
    final l10n = AppLocalizationsFr();
    await tester.pumpApp(
      const FloatingNavBarNavigator(
        // ignore: avoid_redundant_argument_values
        currentTab: FloatingNavBarTab.home,
      ),
      overrides: [
        ...homeScreenOverrides(),
        wishlistsRealtimeProvider.overrideWith(
          (ref) => Stream.error(
            AppException(
              statusCode: 500,
              cause: const SocketException('Failed host lookup'),
            ),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.fling(
      find.byType(CustomScrollView).first,
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.networkErrorTitle), findsOneWidget);
  });
}
