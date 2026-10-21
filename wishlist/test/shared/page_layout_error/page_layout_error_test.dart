import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/page_layout_error/page_layout_error.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';

import '../../pump_app.dart';

void main() {
  final l10n = AppLocalizationsFr();

  testWidgets('explains a network error', (tester) async {
    await tester.pumpApp(
      PageLayoutError(
        error: AppException(
          statusCode: 500,
          cause: const SocketException('Failed host lookup'),
        ),
        onRetry: () async {},
      ),
    );

    expect(find.text(l10n.networkErrorTitle), findsOneWidget);
    expect(find.text(l10n.networkErrorDescription), findsOneWidget);
    expect(find.text(l10n.loadingErrorTitle), findsNothing);
  });

  testWidgets('falls back to a loading error for any other error',
      (tester) async {
    await tester.pumpApp(
      PageLayoutError(
        error: AppException(statusCode: 500, message: 'boom'),
        onRetry: () async {},
      ),
    );

    expect(find.text(l10n.loadingErrorTitle), findsOneWidget);
    expect(find.text(l10n.loadingErrorDescription), findsOneWidget);
    expect(find.text(l10n.networkErrorTitle), findsNothing);
  });

  testWidgets('retries from the button', (tester) async {
    var retries = 0;
    await tester.pumpApp(
      PageLayoutError(
        error: Exception('boom'),
        onRetry: () async => retries++,
      ),
    );

    await tester.tap(find.byType(PrimaryButton));

    expect(retries, 1);
  });

  testWidgets('disables the button while retrying', (tester) async {
    var retries = 0;
    await tester.pumpApp(
      PageLayoutError(
        error: Exception('boom'),
        onRetry: () async => retries++,
        isRetrying: true,
      ),
    );

    final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(button.isLoading, true);

    await tester.tap(find.byType(PrimaryButton));
    expect(retries, 0);
  });

  testWidgets('keeps a failed retry from escaping as an uncaught error',
      (tester) async {
    await tester.pumpApp(
      PageLayoutError(
        error: Exception('boom'),
        onRetry: () async => throw Exception('still offline'),
      ),
    );

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
