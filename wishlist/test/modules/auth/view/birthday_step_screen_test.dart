import 'dart:async';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/auth/view/birthday_step_screen.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/current_user_birthday_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';

import '../../../fixtures/fake_providers.dart';
import '../../../fixtures/mock_supabase.dart';
import '../../../pump_app.dart';

class _HomeStub extends StatelessWidget {
  const _HomeStub();

  @override
  Widget build(BuildContext context) => const Text('home-stub');
}

class _TargetStub extends StatelessWidget {
  const _TargetStub();

  @override
  Widget build(BuildContext context) => const Text('target-stub');
}

void main() {
  setUpAll(() {
    registerFallbackValue(const Birthday(month: 1, day: 1));
  });

  final l10n = AppLocalizationsFr();
  late MockUserService userService;

  setUp(() {
    userService = MockUserService();
    when(() => userService.upsertCurrentUserBirthday(any()))
        .thenAnswer((_) async {});
  });

  Future<void> pumpStep(
    WidgetTester tester, {
    String? redirectTo,
    List<Override> extraOverrides = const [],
  }) async {
    await tester.pumpRouterApp(
      birthdayStepLocation(redirectTo: redirectTo),
      overrides: [
        userServiceProvider.overrideWithValue(userService),
        ...extraOverrides,
      ],
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const _HomeStub(),
          routes: [
            GoRoute(
              path: 'birthday',
              builder: (_, state) => BirthdayStepScreen(
                redirectTo: state.uri.queryParameters['redirectTo'],
              ),
            ),
          ],
        ),
        GoRoute(path: '/wishlist/1', builder: (_, __) => const _TargetStub()),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the illustration without error', (tester) async {
    await pumpStep(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text(l10n.birthdayStepTitle), findsOneWidget);
    expect(find.text(l10n.birthdayStepExplanation), findsOneWidget);
  });

  testWidgets('fits a small screen with the buttons visible', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpStep(tester);

    expect(tester.takeException(), isNull);
    final save = tester.getRect(find.byType(PrimaryButton));
    final later = tester.getRect(find.byType(TextButton));
    expect(save.bottom, lessThanOrEqualTo(568));
    expect(later.bottom, lessThanOrEqualTo(568));
    // "Later" sits right above the main button
    expect(later.bottom, lessThanOrEqualTo(save.top));
  });

  testWidgets('saves the picked value then goes home', (tester) async {
    await pumpStep(tester);

    await tester.drag(
      find.byKey(const ValueKey('birthday-day-picker')),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    final picked = verify(
      () => userService.upsertCurrentUserBirthday(captureAny()),
    ).captured.single as Birthday;
    expect(picked.month, 1);
    expect(picked.day, 3);
    expect(find.text('home-stub'), findsOneWidget);
  });

  testWidgets('saves the default value when nothing is picked', (tester) async {
    await pumpStep(tester);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    verify(
      () => userService
          .upsertCurrentUserBirthday(const Birthday(month: 1, day: 1)),
    ).called(1);
  });

  testWidgets('goes to redirectTo after saving', (tester) async {
    await pumpStep(tester, redirectTo: '/wishlist/1');

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(find.text('target-stub'), findsOneWidget);
    expect(find.text('home-stub'), findsNothing);
  });

  testWidgets('refreshes the birthday shown in the settings after saving',
      (tester) async {
    var reads = 0;
    await pumpStep(
      tester,
      extraOverrides: [
        currentUserBirthdayProvider.overrideWith((ref) async {
          reads++;
          return null;
        }),
      ],
    );
    // Something must be listening for the invalidation to rebuild it
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BirthdayStepScreen)),
    );
    final subscription =
        container.listen(currentUserBirthdayProvider, (_, __) {});
    addTearDown(subscription.close);
    await tester.pump();
    final before = reads;

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(reads, greaterThan(before));
  });

  testWidgets('"later" skips without saving', (tester) async {
    await pumpStep(tester, redirectTo: '/wishlist/1');

    await tester.tap(find.text(l10n.birthdayStepLater));
    await tester.pumpAndSettle();

    verifyNever(() => userService.upsertCurrentUserBirthday(any()));
    expect(find.text('target-stub'), findsOneWidget);
  });

  testWidgets('"later" goes home without redirectTo', (tester) async {
    await pumpStep(tester);

    await tester.tap(find.text(l10n.birthdayStepLater));
    await tester.pumpAndSettle();

    verifyNever(() => userService.upsertCurrentUserBirthday(any()));
    expect(find.text('home-stub'), findsOneWidget);
  });

  testWidgets('an unsafe redirectTo falls back to home', (tester) async {
    await pumpStep(tester, redirectTo: 'https://evil.example/x');

    await tester.tap(find.text(l10n.birthdayStepLater));
    await tester.pumpAndSettle();

    expect(find.text('home-stub'), findsOneWidget);
  });

  testWidgets('an authority-relative redirectTo falls back to home',
      (tester) async {
    await pumpStep(tester, redirectTo: '//evil.com/x');

    await tester.tap(find.text(l10n.birthdayStepLater));
    await tester.pumpAndSettle();

    expect(find.text('home-stub'), findsOneWidget);
  });

  testWidgets('back behaves like "later", keeping redirectTo', (tester) async {
    await pumpStep(tester, redirectTo: '/wishlist/1');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    verifyNever(() => userService.upsertCurrentUserBirthday(any()));
    expect(find.text('target-stub'), findsOneWidget);
    expect(find.text('home-stub'), findsNothing);
  });

  testWidgets('back is ignored while saving', (tester) async {
    final saving = Completer<void>();
    when(() => userService.upsertCurrentUserBirthday(any()))
        .thenAnswer((_) => saving.future);
    await pumpStep(tester, redirectTo: '/wishlist/1');

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.byType(BirthdayStepScreen), findsOneWidget);
    expect(find.text('target-stub'), findsNothing);

    saving.complete();
    await tester.pumpAndSettle();
    expect(find.text('target-stub'), findsOneWidget);
  });

  testWidgets('a save error shows the snackbar and stays on the screen',
      (tester) async {
    when(() => userService.upsertCurrentUserBirthday(any()))
        .thenThrow(AppException(statusCode: 500, message: 'boom'));
    await pumpStep(tester, redirectTo: '/wishlist/1');

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(l10n.genericError), findsOneWidget);
    expect(find.byType(BirthdayStepScreen), findsOneWidget);
    expect(find.text('target-stub'), findsNothing);
    // The user can try again or skip
    expect(find.text(l10n.birthdayStepLater), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testAdaptiveWidgets('$BirthdayStepScreen golden test',
      (tester, variant) async {
    await tester.pumpRouterApp(
      BirthdayStepRoute().location,
      windowConfig: variant,
      overrides: pseudoScreenOverrides(),
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<BirthdayStepScreen>(variant);
  });
}
