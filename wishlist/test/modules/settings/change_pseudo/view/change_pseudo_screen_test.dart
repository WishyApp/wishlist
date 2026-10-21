import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/settings/change_pseudo/view/change_pseudo_screen.dart';
import 'package:wishlist/shared/infra/current_user_profile_provider.dart';

import '../../../../fixtures/fake_providers.dart';
import '../../../../pump_app.dart';

void main() {
  testAdaptiveWidgets('$ChangePseudoScreen golden test',
      (tester, variant) async {
    await tester.pumpApp(
      const ChangePseudoScreen(),
      windowConfig: variant,
      overrides: changePseudoScreenOverrides(),
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<ChangePseudoScreen>(variant);
  });

  testWidgets('shows a single error snackbar when the profile fails to load',
      (tester) async {
    await tester.pumpApp(
      const ChangePseudoScreen(),
      overrides: [
        currentUserProfileProvider
            .overrideWith((ref) async => throw Exception('boom')),
      ],
    );
    await tester.pump();
    await tester.pump();

    final message = AppLocalizationsFr().genericError;
    expect(find.text(message), findsOneWidget);

    // A rebuild while the profile is still failing adds nothing
    tester.view.physicalSize = const Size(500, 900);
    addTearDown(tester.view.reset);
    await tester.pump();
    await tester.pump();
    expect(find.text(message), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
  });
}
