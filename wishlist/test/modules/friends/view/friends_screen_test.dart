import 'package:adaptive_test/adaptive_test.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/modules/friends/view/screens/friends_screen.dart';
import 'package:wishlist/modules/friends/view/widgets/friend_pill.dart';
import 'package:wishlist/modules/friends/view/widgets/user_pill.dart';
import 'package:wishlist/shared/infra/friendships_realtime_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/models/app_user.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/models/profile.dart';
import 'package:wishlist/shared/navigation/floating_nav_bar_navigator.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';
import '../../../fixtures/mock_supabase.dart';
import '../../../pump_app.dart';

void main() {
  setUpAll(() => registerFallbackValue(const ISetConst<String>({})));

  testAdaptiveWidgets('$FriendsScreen golden test', (tester, variant) async {
    await tester.pumpApp(
      const FloatingNavBarNavigator(
        currentTab: FloatingNavBarTab.friends,
      ),
      windowConfig: variant,
      overrides: homeScreenOverrides(),
    );

    // Pump suffisamment pour que les animations se terminent
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.expectGolden<FriendsScreen>(variant);
  });

  testAdaptiveWidgets('$FriendsScreen when empty', (tester, variant) async {
    await tester.pumpApp(
      const FloatingNavBarNavigator(
        currentTab: FloatingNavBarTab.friends,
      ),
      windowConfig: variant,
      overrides: emptyDataOverrides(),
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<FriendsScreen>(variant, suffix: 'empty');
  });

  group('birthday badge', () {
    // Friday, October 23, 2026
    final today = DateTime(2026, 10, 23, 15);

    Birthday inDays(int days) {
      final date = DateTime(today.year, today.month, today.day + days);
      return Birthday(month: date.month, day: date.day);
    }

    Finder pillOf(String pseudo) => find.widgetWithText(FriendPill, pseudo);

    Future<void> pumpFriends(
      WidgetTester tester, {
      required List<Override> overrides,
    }) async {
      await tester.pumpApp(
        const FloatingNavBarNavigator(
          currentTab: FloatingNavBarTab.friends,
        ),
        overrides: overrides,
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }

    testWidgets('shows the countdown of the friends within 30 days',
        (tester) async {
      await pumpFriends(
        tester,
        overrides: homeScreenOverrides(
          now: today,
          birthdays: {
            fakeFriendUserId1: inDays(12),
            fakeFriendUserId2: inDays(30),
          },
        ),
      );

      expect(
        find.descendant(of: pillOf('Alice'), matching: find.text('dans 12 j')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pillOf('Bob'), matching: find.text('dans 30 j')),
        findsOneWidget,
      );
      // The cake tells it is a birthday, not some other deadline
      expect(
        find.descendant(
          of: pillOf('Alice'),
          matching: find.byIcon(Icons.cake_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('says today and tomorrow in words', (tester) async {
      await pumpFriends(
        tester,
        overrides: homeScreenOverrides(
          now: today,
          birthdays: {
            fakeFriendUserId1: inDays(0),
            fakeFriendUserId2: inDays(1),
          },
        ),
      );

      expect(
        find.descendant(
          of: pillOf('Alice'),
          matching: find.text("aujourd'hui"),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pillOf('Bob'), matching: find.text('demain')),
        findsOneWidget,
      );
    });

    testWidgets('has no badge beyond 30 days nor without birthday',
        (tester) async {
      await pumpFriends(
        tester,
        // Alice: 31 days, Bob: unknown birthday
        overrides: homeScreenOverrides(
          now: today,
          birthdays: {fakeFriendUserId1: inDays(31)},
        ),
      );

      expect(find.textContaining('dans '), findsNothing);
      expect(find.text('demain'), findsNothing);
      expect(find.text("aujourd'hui"), findsNothing);
      expect(find.byIcon(Icons.cake_rounded), findsNothing);
    });

    testWidgets('keeps the list order and the pending pills without badge',
        (tester) async {
      await pumpFriends(
        tester,
        overrides: homeScreenOverrides(
          now: today,
          birthdays: {
            fakeFriendUserId1: inDays(20),
            fakeFriendUserId2: inDays(2),
            // Not readable in practice (RLS), the pills ignore them anyway
            fakePendingUserId: inDays(1),
            fakeRequestedUserId: inDays(1),
          },
        ),
      );

      final pseudosFromTop = ['Diana', 'Charlie', 'Alice', 'Bob']..sort(
          (a, b) => tester
              .getTopLeft(find.text(a))
              .dy
              .compareTo(tester.getTopLeft(find.text(b)).dy),
        );
      expect(pseudosFromTop, ['Diana', 'Charlie', 'Alice', 'Bob']);
      expect(find.byType(UserPill), findsNWidgets(2));
      expect(find.text('demain'), findsNothing);
      expect(find.text('dans 20 j'), findsOneWidget);
      expect(find.text('dans 2 j'), findsOneWidget);
    });

    testWidgets('still lists the friends when the birthdays fail to load',
        (tester) async {
      final userService = MockUserService();
      when(() => userService.getVisibleBirthdays(any()))
          .thenThrow(Exception('boom'));

      await pumpFriends(
        tester,
        overrides: [
          ...homeScreenOverrides(now: today, overrideBirthdays: false),
          userServiceProvider.overrideWithValue(userService),
        ],
      );

      expect(find.byType(FriendPill), findsNWidgets(2));
      expect(find.text('Alice'), findsOneWidget);
      expect(find.textContaining('dans '), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the badge and ellipsizes a very long pseudo',
        (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      final longPseudoFriend = AppUser(
        profile: Profile(
          id: fakeFriendUserId1,
          pseudo: 'Un pseudo vraiment beaucoup trop long pour tenir ici',
        ),
        user: fakeFriendAppUser1.user,
      );

      await pumpFriends(
        tester,
        overrides: homeScreenOverrides(
          now: today,
          friendsData: FriendsData(
            friends: [longPseudoFriend].toIList(),
            pendingFriends: const IListConst([]),
            requestedFriends: const IListConst([]),
          ),
          birthdays: {fakeFriendUserId1: inDays(12)},
        ),
      );

      expect(find.text('dans 12 j'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow with a large text scale on 320 px',
        (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpFriends(
        tester,
        overrides: homeScreenOverrides(
          now: today,
          birthdays: {
            fakeFriendUserId1: inDays(0),
            fakeFriendUserId2: inDays(12),
          },
        ),
      );

      expect(find.byType(FriendPill), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  testAdaptiveWidgets('$FriendsScreen with upcoming birthdays',
      (tester, variant) async {
    await tester.pumpApp(
      const FloatingNavBarNavigator(
        currentTab: FloatingNavBarTab.friends,
      ),
      windowConfig: variant,
      overrides: homeScreenOverrides(
        now: DateTime(2026, 10, 23, 15),
        birthdays: {
          fakeFriendUserId1: const Birthday(month: 11, day: 4),
          fakeFriendUserId2: const Birthday(month: 10, day: 24),
        },
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.expectGolden<FriendsScreen>(variant, suffix: 'birthdays');
  });
}
