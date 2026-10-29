import 'dart:io';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/home/view/home_screen.dart';
import 'package:wishlist/modules/home/view/widgets/home_profile_header.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/received_wishes_summary_provider.dart';
import 'package:wishlist/shared/infra/repositories/user/user_streams_providers.dart';
import 'package:wishlist/shared/infra/wishlists_realtime_provider.dart';
import 'package:wishlist/shared/models/received_wishes_summary/received_wishes_summary.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/navigation/floating_nav_bar_navigator.dart';
import 'package:wishlist/shared/page_layout_empty/page_layout_empty.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';

import '../../../fixtures/fake_data.dart';

import '../../../fixtures/fake_providers.dart';
import '../../../pump_app.dart';

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
          ...homeScreenOverrides(now: fakeNow),
          summaryOverride,
          wishlistsRealtimeProvider.overrideWith((ref) => wishlists),
        ],
      );
    }

    testWidgets('while the wishlists load', (tester) async {
      await pumpHome(tester, const Stream.empty());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(HomeProfileHeader), findsOneWidget);
      expect(find.text('MonPseudo'), findsOneWidget);
      expect(find.text('2 wishs reçus'), findsOneWidget);
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
}
