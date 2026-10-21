import 'dart:io';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/friends/view/screens/friend_details_screen.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/friend_details_realtime_provider.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';
import '../../../pump_app.dart';

void main() {
  testAdaptiveWidgets('$FriendDetailsScreen golden test',
      (tester, variant) async {
    await tester.pumpRouterApp(
      FriendDetailsRoute(fakeFriendUserId1).location,
      windowConfig: variant,
      overrides: friendDetailsScreenOverrides(friendId: fakeFriendUserId1),
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<FriendDetailsScreen>(variant);
  });

  testAdaptiveWidgets('$FriendDetailsScreen when empty',
      (tester, variant) async {
    await tester.pumpRouterApp(
      FriendDetailsRoute(fakeFriendUserId1).location,
      windowConfig: variant,
      overrides: friendDetailsScreenOverrides(
        friendId: fakeFriendUserId1,
        friendDetails: fakeFriendDetailsEmpty,
      ),
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<FriendDetailsScreen>(variant, suffix: 'empty');
  });

  testWidgets('$FriendDetailsScreen explains a load error and retries',
      (tester) async {
    final l10n = AppLocalizationsFr();
    var loads = 0;

    await tester.pumpPushedScreen(
      const FriendDetailsScreen(friendId: fakeFriendUserId1),
      overrides: [
        supabaseClientOverride(),
        friendDetailsRealtimeProvider(fakeFriendUserId1).overrideWith((ref) {
          loads++;
          return loads == 1
              ? Stream.error(
                  AppException(
                    statusCode: 500,
                    cause: const SocketException('Failed host lookup'),
                  ),
                )
              : Stream.value(fakeFriendDetails);
        }),
      ],
    );

    expect(find.text(l10n.networkErrorTitle), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text(l10n.networkErrorTitle), findsNothing);
    expect(find.text(fakeFriendDetails.appUser.profile.pseudo), findsWidgets);
    // The loaded screen has a single Scaffold, besides the one of the test app
    expect(find.byType(Scaffold), findsNWidgets(2));
  });
}
