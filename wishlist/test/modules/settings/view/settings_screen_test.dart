import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/modules/settings/view/settings_screen.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/navigation/routes.dart';

import '../../../fixtures/fake_providers.dart';
import '../../../fixtures/mock_supabase.dart';
import '../../../pump_app.dart';

void main() {
  testAdaptiveWidgets('$SettingsScreen golden test', (tester, variant) async {
    await tester.pumpRouterApp(
      SettingsRoute().location,
      windowConfig: variant,
      overrides: settingsScreenOverrides(),
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<SettingsScreen>(variant);
  });

  // Juste après la déconnexion, l'écran est reconstruit une fois avant la
  // redirection : plus d'utilisateur courant, donc plus d'email.
  testWidgets('builds without a signed-in user', (tester) async {
    final userService = createMockUserService();
    when(userService.getCurrentUserEmail).thenReturn(null);

    await tester.pumpRouterApp(
      SettingsRoute().location,
      // settingsScreenOverrides, sauf le UserService
      overrides: [
        supabaseClientOverride(),
        userServiceProvider.overrideWithValue(userService),
        watchCurrentUserProfileOverride(),
        appInfoOverride(),
      ],
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('test@example.com'), findsNothing);
  });
}
