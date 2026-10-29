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

  group('onClosed', () {
    Future<void> pumpTrigger(
      WidgetTester tester, {
      required VoidCallback onClosed,
      VoidCallback? onAction,
      bool autoClose = true,
      void Function(VoidCallback close)? onShown,
    }) async {
      await tester.pumpApp(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                final close = showAppSnackBar(
                  context,
                  'Done',
                  type: SnackBarType.success,
                  actionLabel: onAction == null ? null : 'See',
                  onAction: onAction,
                  onClosed: onClosed,
                  autoClose: autoClose,
                );
                onShown?.call(close);
              },
              child: const Text('Trigger'),
            );
          },
        ),
      );
      await tester.tap(find.text('Trigger'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
    }

    testWidgets('fires when the delay is over', (tester) async {
      var closed = 0;
      await pumpTrigger(tester, onClosed: () => closed++);
      expect(closed, 0);

      await tester.pump(const Duration(seconds: 4));
      expect(closed, 1);
      await tester.pumpAndSettle();
      expect(closed, 1);
    });

    testWidgets('fires when swiped away', (tester) async {
      var closed = 0;
      await pumpTrigger(tester, onClosed: () => closed++);

      await tester.drag(find.text('Done'), const Offset(600, 0));
      await tester.pumpAndSettle();

      expect(closed, 1);
      expect(find.text('Done'), findsNothing);
    });

    testWidgets('fires when tapped away', (tester) async {
      var closed = 0;
      await pumpTrigger(tester, onClosed: () => closed++);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(closed, 1);
    });

    testWidgets('does not fire after the action', (tester) async {
      var closed = 0;
      var actions = 0;
      await pumpTrigger(
        tester,
        onClosed: () => closed++,
        onAction: () => actions++,
      );

      await tester.tap(find.text('See'));
      await tester.pumpAndSettle();

      expect(actions, 1);
      expect(closed, 0);
    });

    testWidgets('ignores the action once the delay closed it', (tester) async {
      var closed = 0;
      var actions = 0;
      await pumpTrigger(
        tester,
        onClosed: () => closed++,
        onAction: () => actions++,
      );

      // The delay is over: the button is still there during the exit
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 50));
      expect(closed, 1);
      expect(find.text('See'), findsOneWidget);
      // The tap of a finger that came just before the button left
      tester.widget<TextButton>(find.byType(TextButton)).onPressed?.call();
      await tester.pumpAndSettle();

      expect(actions, 0);
      expect(closed, 1);
    });

    testWidgets('does not fire when the caller closes it', (tester) async {
      var closed = 0;
      late VoidCallback close;
      await pumpTrigger(
        tester,
        onClosed: () => closed++,
        onShown: (c) => close = c,
      );

      close();
      await tester.pump();
      close();
      await tester.pump(const Duration(seconds: 5));

      expect(find.text('Done'), findsNothing);
      expect(closed, 0);
    });

    testWidgets('stays open past the delay without autoClose', (tester) async {
      var closed = 0;
      late VoidCallback close;
      await pumpTrigger(
        tester,
        onClosed: () => closed++,
        autoClose: false,
        onShown: (c) => close = c,
      );

      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Done'), findsOneWidget);
      expect(closed, 0);

      close();
      await tester.pump();
    });
  });
}
