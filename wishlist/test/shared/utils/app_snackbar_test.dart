import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/utils/app_snackbar.dart';

import '../../pump_app.dart';

void main() {
  group('showGenericError with AppUserMessageKey.inputTooLong', () {
    testWidgets(
        'should display input too long message when error has userMessageKey '
        'inputTooLong', (tester) async {
      await tester.pumpApp(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showGenericError(
                  context,
                  error: AppException(
                    statusCode: 400,
                    message: 'db constraint',
                    userMessageKey: AppUserMessageKey.inputTooLong,
                  ),
                );
              },
              child: const Text('Trigger error'),
            );
          },
        ),
      );

      final l10n = AppLocalizationsFr();

      await tester.tap(find.text('Trigger error'));
      await tester.pump(); // run addPostFrameCallback
      await tester.pump(const Duration(milliseconds: 100)); // build overlay

      expect(find.text(l10n.inputTooLong), findsOneWidget);
    });

    testWidgets(
        'should display generic error message when error has no userMessageKey',
        (tester) async {
      await tester.pumpApp(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showGenericError(
                  context,
                  error: AppException(
                    statusCode: 500,
                    message: 'Server error',
                  ),
                );
              },
              child: const Text('Trigger error'),
            );
          },
        ),
      );

      final l10n = AppLocalizationsFr();

      await tester.tap(find.text('Trigger error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text(l10n.genericError),
        findsOneWidget,
      );
    });
  });

  testWidgets(
      'showGenericError asks to check the connection on a network '
      'error', (tester) async {
    await tester.pumpApp(
      Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showGenericError(
                context,
                error: AppException(
                  statusCode: 500,
                  message: 'Failed to update wish',
                  cause: const SocketException('Failed host lookup'),
                ),
              );
            },
            child: const Text('Trigger error'),
          );
        },
      ),
    );

    final l10n = AppLocalizationsFr();

    await tester.tap(find.text('Trigger error'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l10n.networkError), findsOneWidget);
  });

  testWidgets('runs the action and closes the snackbar on its button',
      (tester) async {
    var actions = 0;
    await tester.pumpApp(
      Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showAppSnackBar(
                context,
                'Done',
                type: SnackBarType.success,
                actionLabel: 'See',
                onAction: () => actions++,
              );
            },
            child: const Text('Trigger'),
          );
        },
      ),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Done'), findsOneWidget);

    // A second tap during the exit animation does nothing
    await tester.tap(find.text('See'));
    await tester.pump();
    await tester.tap(find.text('See'), warnIfMissed: false);
    await tester.pump();
    expect(actions, 1);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('colors the action with the theme of the calling screen',
      (tester) async {
    await tester.pumpApp(
      Theme(
        data: ThemeData(primaryColor: Colors.indigo),
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showAppSnackBar(
                  context,
                  'Done',
                  type: SnackBarType.success,
                  actionLabel: 'See',
                  onAction: () {},
                );
              },
              child: const Text('Trigger'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(tester.widget<Text>(find.text('See')).style?.color, Colors.indigo);
    await tester.pumpAndSettle();
  });

  testWidgets('darkens a light theme color to keep the action readable',
      (tester) async {
    const yellow = Color(0xFFDBCD4D);
    await tester.pumpApp(
      Theme(
        data: ThemeData(primaryColor: yellow),
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showAppSnackBar(
                  context,
                  'Done',
                  type: SnackBarType.success,
                  actionLabel: 'See',
                  onAction: () {},
                );
              },
              child: const Text('Trigger'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    final color = tester.widget<Text>(find.text('See')).style!.color!;
    expect(color, isNot(yellow));
    expect(
      AppColors.contrastRatio(color, Colors.white),
      greaterThanOrEqualTo(4.5),
    );
    await tester.pumpAndSettle();
  });
}
