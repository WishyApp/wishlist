import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/modules/wishs/view/widgets/consult_wish_info_container.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/infra/wish_taken_by_user_service.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/mock_supabase.dart';
import '../../../pump_app.dart';

class MockWishTakenByUserService extends Mock
    implements WishTakenByUserService {}

void main() {
  testWidgets('tapping "give it" while signed out does nothing',
      (tester) async {
    final session = FakeAuthSession(userId: 'user-a');
    addTearDown(session.close);
    // Like the real service: throws without a signed-in user.
    final userService = MockUserService();
    when(userService.getCurrentUserId).thenThrow(StateError('signed out'));
    final wishTakenByUserService = MockWishTakenByUserService();

    await tester.pumpApp(
      ConsultWishInfoContainer(wish: fakeWish1, descriptionText: ''),
      overrides: [
        supabaseClientProvider.overrideWithValue(session.client),
        userServiceProvider.overrideWithValue(userService),
        wishTakenByUserServiceProvider
            .overrideWithValue(wishTakenByUserService),
      ],
    );
    await tester.pump();

    // The screen is still mounted while the router redirects.
    session.signOut();
    await tester.pump();
    await tester.tap(find.text("Je veux l'offrir").last);
    await tester.pump();

    expect(tester.takeException(), isNull);
    verifyZeroInteractions(wishTakenByUserService);
  });
}
