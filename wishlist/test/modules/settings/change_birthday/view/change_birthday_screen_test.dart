import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/settings/change_birthday/view/change_birthday_screen.dart';
import 'package:wishlist/modules/settings/view/settings_screen.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/navigation/routes.dart';

import '../../../../fixtures/fake_providers.dart';
import '../../../../fixtures/mock_supabase.dart';
import '../../../../pump_app.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(const Birthday(month: 1, day: 1));
  });

  late MockUserService userService;

  setUp(() {
    userService = MockUserService();
    when(() => userService.upsertCurrentUserBirthday(any()))
        .thenAnswer((_) async {});
    when(() => userService.deleteCurrentUserBirthday())
        .thenAnswer((_) async {});
  });

  /// Opens the screen from the settings, like in the app, so that it can pop
  /// back to them.
  Future<void> pumpScreen(WidgetTester tester, {Birthday? birthday}) async {
    await tester.pumpRouterApp(
      SettingsRoute().location,
      overrides: [
        ...settingsScreenOverrides(currentUserBirthday: birthday),
        userServiceProvider.overrideWithValue(userService),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsFr().settingsScreenBirthday));
    await tester.pumpAndSettle();
  }

  final l10n = AppLocalizationsFr();

  /// Lets the call and the pop through, without running the snackbar (which
  /// only lives 4 seconds) to its end.
  Future<void> pumpAction(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Runs the snackbar to its end so that no timer is left.
  Future<void> flushSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('saves the initial value of an existing birthday',
      (tester) async {
    await pumpScreen(tester, birthday: const Birthday(month: 3, day: 12));

    await tester.tap(find.text(l10n.changeBirthdayConfirm).first);
    await pumpAction(tester);

    verify(
      () => userService
          .upsertCurrentUserBirthday(const Birthday(month: 3, day: 12)),
    ).called(1);
    // Back on the previous route, with the success snackbar
    expect(find.byType(ChangeBirthdayScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text(l10n.changeBirthdaySuccess), findsOneWidget);
    await flushSnackBar(tester);
  });

  testWidgets('saves the value picked on the wheels', (tester) async {
    await pumpScreen(tester, birthday: const Birthday(month: 3, day: 12));

    await tester.drag(
      find.byKey(const ValueKey('birthday-day-picker')),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.changeBirthdayConfirm).first);
    await pumpAction(tester);
    await flushSnackBar(tester);

    verify(
      () => userService
          .upsertCurrentUserBirthday(const Birthday(month: 3, day: 14)),
    ).called(1);
  });

  testWidgets('hides the remove button when no birthday is set',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text(l10n.changeBirthdayRemove), findsNothing);
  });

  testWidgets('cannot save the default date before a wheel moved',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text(l10n.changeBirthdayConfirm).first);
    await pumpAction(tester);

    verifyNever(() => userService.upsertCurrentUserBirthday(any()));
    expect(find.byType(ChangeBirthdayScreen), findsOneWidget);
  });

  testWidgets('saves once a wheel moved, with no birthday set', (tester) async {
    await pumpScreen(tester);

    await tester.drag(
      find.byKey(const ValueKey('birthday-day-picker')),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.changeBirthdayConfirm).first);
    await pumpAction(tester);
    await flushSnackBar(tester);

    verify(
      () => userService
          .upsertCurrentUserBirthday(const Birthday(month: 1, day: 3)),
    ).called(1);
  });

  testWidgets('removes the birthday', (tester) async {
    await pumpScreen(tester, birthday: const Birthday(month: 3, day: 12));

    await tester.tap(find.text(l10n.changeBirthdayRemove).first);
    await pumpAction(tester);

    verify(() => userService.deleteCurrentUserBirthday()).called(1);
    verifyNever(() => userService.upsertCurrentUserBirthday(any()));
    expect(find.byType(ChangeBirthdayScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text(l10n.changeBirthdayRemoved), findsOneWidget);
    await flushSnackBar(tester);
  });

  testWidgets('stays on the screen and shows an error when saving fails',
      (tester) async {
    when(() => userService.upsertCurrentUserBirthday(any())).thenThrow(
      AppException(statusCode: 500, message: 'boom'),
    );
    await pumpScreen(tester, birthday: const Birthday(month: 3, day: 12));

    await tester.tap(find.text(l10n.changeBirthdayConfirm).first);
    await pumpAction(tester);

    expect(find.byType(ChangeBirthdayScreen), findsOneWidget);
    expect(find.text(l10n.genericError), findsOneWidget);
    await flushSnackBar(tester);
  });

  testWidgets('offers to retry when the birthday fails to load',
      (tester) async {
    var calls = 0;
    when(() => userService.getCurrentUserBirthday()).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw AppException(statusCode: 500, message: 'boom');
      }
      return const Birthday(month: 3, day: 12);
    });
    await tester.pumpRouterApp(
      SettingsRoute().location,
      overrides: [
        ...settingsScreenOverrides(overrideBirthday: false),
        userServiceProvider.overrideWithValue(userService),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.settingsScreenBirthday));
    await tester.pumpAndSettle();
    await flushSnackBar(tester);

    expect(find.text(l10n.retryButton), findsWidgets);
    expect(find.text(l10n.changeBirthdayConfirm), findsNothing);

    await tester.tap(find.text(l10n.retryButton).first);
    await tester.pumpAndSettle();

    expect(find.text(l10n.changeBirthdayConfirm), findsWidgets);
    expect(find.text(l10n.changeBirthdayRemove), findsWidgets);
  });

  group('settings line, with the real provider on top of the service', () {
    late Birthday? stored;

    setUp(() {
      stored = const Birthday(month: 3, day: 12);
      when(() => userService.getCurrentUserBirthday())
          .thenAnswer((_) async => stored);
      when(() => userService.upsertCurrentUserBirthday(any()))
          .thenAnswer((invocation) async {
        stored = invocation.positionalArguments.first as Birthday;
      });
      when(() => userService.deleteCurrentUserBirthday()).thenAnswer((_) async {
        stored = null;
      });
    });

    Future<void> openScreen(WidgetTester tester) async {
      await tester.pumpRouterApp(
        SettingsRoute().location,
        overrides: [
          ...settingsScreenOverrides(overrideBirthday: false),
          userServiceProvider.overrideWithValue(userService),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the new value after a save, not set after a remove',
        (tester) async {
      await openScreen(tester);
      expect(find.text('12 mars'), findsOneWidget);

      await tester.tap(find.text(l10n.settingsScreenBirthday));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('birthday-day-picker')),
        const Offset(0, -80),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.changeBirthdayConfirm).first);
      await pumpAction(tester);
      await flushSnackBar(tester);

      expect(find.text('12 mars'), findsNothing);
      expect(find.text('14 mars'), findsOneWidget);

      await tester.tap(find.text(l10n.settingsScreenBirthday));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.changeBirthdayRemove).first);
      await pumpAction(tester);
      await flushSnackBar(tester);

      expect(find.text('14 mars'), findsNothing);
      expect(find.text(l10n.settingsScreenBirthdayNotSet), findsOneWidget);
    });
  });
}
