import 'dart:io';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/wishs/view/screens/add_wish_screen.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/wishlists_realtime_provider.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';

import '../../../../fixtures/fake_data.dart';
import '../../../../fixtures/fake_providers.dart';
import '../../../../pump_app.dart';

void main() {
  testAdaptiveWidgets('$AddWishScreen golden test with multiple wishlists',
      (tester, variant) async {
    await tester.pumpApp(
      const AddWishScreen(),
      windowConfig: variant,
      overrides: [
        wishlistsRealtimeOverride(
          wishlists: [fakeWishlist1, fakeWishlist2, fakeWishlist3],
        ),
      ],
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<AddWishScreen>(variant);
  });

  testWidgets('$AddWishScreen shows a back button while it loads',
      (tester) async {
    await tester.pumpPushedScreen(
      const AddWishScreen(),
      overrides: [
        wishlistsRealtimeProvider.overrideWith((ref) => const Stream.empty()),
      ],
      settle: false,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('$AddWishScreen explains a load error and retries',
      (tester) async {
    final l10n = AppLocalizationsFr();
    var loads = 0;

    await tester.pumpPushedScreen(
      const AddWishScreen(),
      overrides: [
        wishlistsRealtimeProvider.overrideWith((ref) {
          loads++;
          return loads == 1
              ? Stream.error(
                  AppException(
                    statusCode: 500,
                    cause: const SocketException('Failed host lookup'),
                  ),
                )
              : Stream.value([fakeWishlist1, fakeWishlist2, fakeWishlist3]);
        }),
      ],
    );

    expect(find.text(l10n.networkErrorTitle), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text(l10n.networkErrorTitle), findsNothing);
    expect(find.text(fakeWishlist1.name), findsOneWidget);
  });
}
