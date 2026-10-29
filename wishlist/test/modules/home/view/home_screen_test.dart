import 'dart:io';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/home/view/home_screen.dart';
import 'package:wishlist/modules/home/view/widgets/home_profile_header.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/wishlists_realtime_provider.dart';
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
}
