import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';
import 'package:wishlist/shared/widgets/error_page_with_back.dart';

import '../../pump_app.dart';

void main() {
  final l10n = AppLocalizationsFr();

  testWidgets('shows the unavailable message with the route back button',
      (tester) async {
    await tester.pumpPushedScreen(
      ErrorPageWithBack.unavailable(message: 'Gone'),
    );

    expect(find.text('Gone'), findsOneWidget);
    expect(find.byType(PrimaryButton), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('explains a failure and retries', (tester) async {
    var retries = 0;

    await tester.pumpPushedScreen(
      ErrorPageWithBack.failure(
        error: AppException(
          statusCode: 500,
          cause: const SocketException('Failed host lookup'),
        ),
        onRetry: () async => retries++,
      ),
    );

    expect(find.text(l10n.networkErrorTitle), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(retries, 1);
  });

  testWidgets('onBack makes the back button explicit', (tester) async {
    var backs = 0;

    await tester.pumpApp(
      ErrorPageWithBack.unavailable(
        message: 'Gone',
        onBack: () => backs++,
      ),
    );

    expect(find.byType(BackButton), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back));

    expect(backs, 1);
  });
}
