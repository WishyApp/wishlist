import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/completed_wishes/view/completed_wishes_screen.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_repository.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_repository_provider.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';
import '../../../pump_app.dart';

class _MockUserCompletedWishRepository extends Mock
    implements UserCompletedWishRepository {}

void main() {
  final l10n = AppLocalizationsFr();

  CompletedWishWithDetails completed(
    int id, {
    required String name,
    int quantity = 1,
    DateTime? completedAt,
  }) =>
      CompletedWishWithDetails(
        wish: Wish(
          id: id,
          createdAt: fakeCreatedAt,
          name: name,
          description: '',
          quantity: quantity,
          wishlistId: fakeWishlist1.id,
          updatedBy: fakeCurrentUserId,
          updatedAt: fakeUpdatedAt,
        ),
        fromWishlistId: fakeWishlist1.id,
        fromWishlistName: fakeWishlist1.name,
        ownerPseudo: 'Me',
        ownerId: fakeCurrentUserId,
        completedAt: completedAt ?? DateTime(2026, 3, 5),
        quantity: 1,
      );

  Future<_MockUserCompletedWishRepository> pumpScreen(
    WidgetTester tester,
    List<CompletedWishWithDetails> items,
  ) async {
    final repository = _MockUserCompletedWishRepository();
    // A router: the dialogs close through it
    await tester.pumpRouterApp(
      '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const CompletedWishesScreen(),
        ),
      ],
      overrides: [
        supabaseClientOverride(),
        userServiceOverride(),
        ...completedWishesOverrides(
          fakeCurrentUserId,
          receipts: () => Stream.value(items.toIList()),
        ),
        userCompletedWishRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pumpAndSettle();
    return repository;
  }

  group('options of a completed wish', () {
    testWidgets('offer the date, the quantity and the removal', (tester) async {
      await pumpScreen(tester, [completed(1, name: 'Plaid', quantity: 2)]);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text(l10n.modifyCompletionDate), findsOneWidget);
      expect(find.text(l10n.modifyCompletedQuantity), findsOneWidget);
      expect(find.text(l10n.unmarkWishAsCompleted), findsOneWidget);
    });

    testWidgets('leave out the quantity of a single wish', (tester) async {
      await pumpScreen(tester, [completed(1, name: 'Plaid')]);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text(l10n.modifyCompletionDate), findsOneWidget);
      expect(find.text(l10n.modifyCompletedQuantity), findsNothing);
    });

    Future<_MockUserCompletedWishRepository> openDateDialog(
      WidgetTester tester,
      CompletedWishWithDetails item,
    ) async {
      final repository = await pumpScreen(tester, [item]);
      when(
        () => repository.updateCompletionDate(
          userId: any(named: 'userId'),
          wishId: any(named: 'wishId'),
          completedAt: any(named: 'completedAt'),
        ),
      ).thenAnswer((_) async {});

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.modifyCompletionDate));
      await tester.pumpAndSettle();
      return repository;
    }

    Future<void> tapSave(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(PrimaryButton),
        ),
      );
      // Not settled: the snackbar would be gone
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('change the completion date from the saved one',
        (tester) async {
      final item = completed(1, name: 'Plaid', completedAt: DateTime(2025, 12));
      final repository = await openDateDialog(tester, item);

      // The dialog of the completion, its wheels on the saved day
      expect(
        find.text(l10n.completionDateDialogExplanation(1)),
        findsOneWidget,
      );
      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(picker.initialDateTime, DateTime(2025, 12));

      picker.onDateTimeChanged(DateTime(2025, 12, 24));
      await tapSave(tester);

      verify(
        () => repository.updateCompletionDate(
          userId: fakeCurrentUserId,
          wishId: item.wish.id,
          completedAt: DateTime(2025, 12, 24),
        ),
      ).called(1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(l10n.updateSuccess), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('save nothing when the date is kept', (tester) async {
      final item = completed(1, name: 'Plaid', completedAt: DateTime(2025, 12));
      final repository = await openDateDialog(tester, item);

      await tapSave(tester);

      verifyNever(
        () => repository.updateCompletionDate(
          userId: any(named: 'userId'),
          wishId: any(named: 'wishId'),
          completedAt: any(named: 'completedAt'),
        ),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(l10n.updateSuccess), findsNothing);
    });

    testWidgets('bring a saved day after today back to today', (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final item = completed(
        1,
        name: 'Plaid',
        completedAt: today.add(const Duration(days: 2)),
      );
      final repository = await openDateDialog(tester, item);

      expect(
        tester
            .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
            .initialDateTime,
        today,
      );
      await tapSave(tester);

      verify(
        () => repository.updateCompletionDate(
          userId: fakeCurrentUserId,
          wishId: item.wish.id,
          completedAt: today,
        ),
      ).called(1);
      await tester.pumpAndSettle();
    });

    testWidgets('explain a failed change of the date', (tester) async {
      final item = completed(1, name: 'Plaid', completedAt: DateTime(2025, 12));
      final repository = await openDateDialog(tester, item);
      when(
        () => repository.updateCompletionDate(
          userId: any(named: 'userId'),
          wishId: any(named: 'wishId'),
          completedAt: any(named: 'completedAt'),
        ),
      ).thenThrow(Exception('boom'));

      tester
          .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
          .onDateTimeChanged(DateTime(2025, 12, 24));
      await tapSave(tester);

      expect(find.text(l10n.genericError), findsOneWidget);
      expect(find.text(l10n.updateSuccess), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('change the completed quantity up to the wish quantity',
        (tester) async {
      final item = completed(1, name: 'Plaid', quantity: 3);
      final repository = await pumpScreen(tester, [item]);
      when(
        () => repository.updateCompletedWishQuantity(
          userId: any(named: 'userId'),
          wishId: any(named: 'wishId'),
          newQuantity: any(named: 'newQuantity'),
        ),
      ).thenAnswer((_) async {});

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.modifyCompletedQuantity));
      await tester.pumpAndSettle();

      // Starts on the saved quantity (1), the wish quantity is the most
      expect(find.text(l10n.selectQuantityToComplete), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '3');
      await tester.pumpAndSettle();
      await tapSave(tester);

      verify(
        () => repository.updateCompletedWishQuantity(
          userId: fakeCurrentUserId,
          wishId: item.wish.id,
          newQuantity: 3,
        ),
      ).called(1);
      expect(find.text(l10n.updateSuccess), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('change nothing when the date dialog is cancelled',
        (tester) async {
      final repository = await pumpScreen(tester, [completed(1, name: 'A')]);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.modifyCompletionDate));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(SecondaryButton),
        ),
      );
      await tester.pumpAndSettle();

      verifyZeroInteractions(repository);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('lead to the removal confirmation', (tester) async {
      await pumpScreen(tester, [completed(1, name: 'Plaid')]);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.unmarkWishAsCompleted));
      await tester.pumpAndSettle();

      expect(find.text(l10n.unmarkWishConfirmTitle), findsOneWidget);
      expect(
        find.text(l10n.unmarkWishConfirmMessage(fakeWishlist1.name)),
        findsOneWidget,
      );
    });
  });

  testWidgets('keeps the order of the completions within a day',
      (tester) async {
    // As the repository gives them: the last completed first
    await pumpScreen(tester, [
      completed(1, name: 'Second of the day'),
      completed(2, name: 'Earlier day', completedAt: DateTime(2026, 3, 4)),
      completed(3, name: 'First of the day'),
    ]);

    double top(String name) => tester.getTopLeft(find.text(name)).dy;

    expect(top('Second of the day'), lessThan(top('First of the day')));
    expect(top('First of the day'), lessThan(top('Earlier day')));
  });
}
