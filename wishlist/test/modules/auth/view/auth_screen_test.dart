import 'package:adaptive_test/adaptive_test.dart';
import 'package:wishlist/modules/auth/view/auth_screen.dart';
import 'package:wishlist/shared/navigation/routes.dart';

import '../../../fixtures/fake_providers.dart';
import '../../../pump_app.dart';

void main() {
  testAdaptiveWidgets('$AuthScreen golden test', (tester, variant) async {
    await tester.pumpRouterApp(
      AuthRoute().location,
      windowConfig: variant,
      overrides: [configOverride()],
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<AuthScreen>(variant);
  });
}
