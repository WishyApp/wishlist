import 'dart:io';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/friends/view/screens/friend_details_screen.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/friend_details_realtime_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/models/app_user.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/models/friend_details/friend_details.dart';
import 'package:wishlist/shared/models/profile.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';
import 'package:wishlist/shared/widgets/wishlist_card.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';
import '../../../fixtures/mock_supabase.dart';
import '../../../pump_app.dart';

void main() {
  setUpAll(() => registerFallbackValue(const ISetConst<String>({})));

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

  group('birthday', () {
    // Friday, October 23, 2026
    final today = DateTime(2026, 10, 23, 15);

    Future<void> pumpDetails(
      WidgetTester tester, {
      Map<String, Birthday>? birthdays,
      bool overrideBirthdays = true,
      List<Override> extraOverrides = const [],
    }) {
      return tester.pumpPushedScreen(
        const FriendDetailsScreen(friendId: fakeFriendUserId1),
        overrides: [
          ...friendDetailsScreenOverrides(
            friendId: fakeFriendUserId1,
            now: today,
            birthdays: birthdays,
            overrideBirthdays: overrideBirthdays,
          ),
          ...extraOverrides,
        ],
      );
    }

    testWidgets('shows the date and the countdown within 30 days',
        (tester) async {
      await pumpDetails(
        tester,
        birthdays: {fakeFriendUserId1: const Birthday(month: 10, day: 28)},
      );

      expect(find.text('28 octobre · dans 5 jours'), findsOneWidget);
      expect(find.byIcon(Icons.cake_rounded), findsOneWidget);
    });

    // (month, day, expected line): the countdown stops after 30 days
    const lines = [
      (10, 24, '24 octobre · demain'),
      (10, 23, "23 octobre · aujourd'hui !"),
      (11, 22, '22 novembre · dans 30 jours'),
      (11, 23, '23 novembre'),
    ];
    for (final (month, day, line) in lines) {
      testWidgets('shows "$line"', (tester) async {
        await pumpDetails(
          tester,
          birthdays: {
            fakeFriendUserId1: Birthday(month: month, day: day),
          },
        );

        expect(find.text(line), findsOneWidget);
      });
    }

    testWidgets('shows nothing without a visible birthday', (tester) async {
      await pumpDetails(tester);

      expect(find.byIcon(Icons.cake_rounded), findsNothing);
      expect(find.text(fakeFriendDetails.appUser.profile.pseudo), findsWidgets);
    });

    testWidgets('shows the page when the birthdays fail to load',
        (tester) async {
      final userService = MockUserService();
      when(() => userService.getVisibleBirthdays(any()))
          .thenThrow(Exception('boom'));

      await pumpDetails(
        tester,
        overrideBirthdays: false,
        extraOverrides: [
          emptyFriendshipsRealtimeOverride(),
          userServiceProvider.overrideWithValue(userService),
        ],
      );

      expect(find.byIcon(Icons.cake_rounded), findsNothing);
      expect(find.text(fakeFriendDetails.appUser.profile.pseudo), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow with a long pseudo on a small screen',
        (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);

      await pumpDetails(
        tester,
        birthdays: {fakeFriendUserId1: const Birthday(month: 10, day: 28)},
        extraOverrides: [
          friendDetailsRealtimeOverride(
            fakeFriendUserId1,
            friendDetails: FriendDetails(
              appUser: AppUser(
                profile: Profile(
                  id: fakeFriendUserId1,
                  pseudo: 'Un pseudo vraiment beaucoup trop long pour la page',
                ),
                user: fakeFriendAppUser1.user,
              ),
              mutualFriends: const ISetConst({}),
              publicWishlists: const IListConst([]),
              nbWishlists: 0,
              nbWishs: 0,
            ),
          ),
        ],
      );

      expect(find.textContaining('28 octobre'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
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

  testWidgets(
      '$FriendDetailsScreen keeps the last wishlist above the home '
      'indicator', (tester) async {
    const bottomInset = 34.0;
    // Short enough for the list to scroll
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 400)
      ..padding = const FakeViewPadding(bottom: bottomInset)
      ..viewPadding = const FakeViewPadding(bottom: bottomInset);
    addTearDown(tester.view.reset);

    await tester.pumpPushedScreen(
      const FriendDetailsScreen(friendId: fakeFriendUserId1),
      overrides: friendDetailsScreenOverrides(friendId: fakeFriendUserId1),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
    await tester.pumpAndSettle();

    final lastWishlist = find.byType(WishlistCard).last;
    expect(
      tester.getBottomLeft(lastWishlist).dy,
      lessThanOrEqualTo(400 - bottomInset),
    );
  });

  testAdaptiveWidgets('$FriendDetailsScreen with a birthday',
      (tester, variant) async {
    await tester.pumpRouterApp(
      FriendDetailsRoute(fakeFriendUserId1).location,
      windowConfig: variant,
      overrides: friendDetailsScreenOverrides(
        friendId: fakeFriendUserId1,
        now: DateTime(2026, 10, 23, 15),
        birthdays: {fakeFriendUserId1: const Birthday(month: 10, day: 28)},
      ),
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<FriendDetailsScreen>(variant, suffix: 'birthday');
  });
}
