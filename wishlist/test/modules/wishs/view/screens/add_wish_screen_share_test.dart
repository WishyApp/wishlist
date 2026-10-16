import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/modules/wishs/view/screens/add_wish_screen.dart';
import 'package:wishlist/shared/infra/share_intent_payload_provider.dart';
import 'package:wishlist/shared/models/share_intent_payload/share_intent_payload.dart';
import 'package:wishlist/shared/models/wish_prefill_data/wish_prefill_data.dart';

import '../../../../fixtures/fake_data.dart';
import '../../../../fixtures/fake_providers.dart';
import '../../../../pump_app.dart';

void main() {
  testWidgets(
      'consumes a share received while the wishlist picker is already shown',
      (tester) async {
    await tester.pumpApp(
      const AddWishScreen(),
      overrides: [
        wishlistsRealtimeOverride(
          wishlists: [fakeWishlist1, fakeWishlist2, fakeWishlist3],
        ),
      ],
    );
    final container =
        ProviderScope.containerOf(tester.element(find.byType(AddWishScreen)));
    final notifier =
        container.read(shareIntentPayloadNotifierProvider.notifier);

    // 1er partage, lu au montage.
    notifier.setPayload(
      prefill: const WishPrefillData(linkUrl: 'https://shop.fr/a'),
    );
    await tester.pumpAndSettle();

    // 2e partage alors que l'écran de choix est toujours affiché : même
    // adresse, même State, initState ne repasse pas.
    notifier.setPayload(
      prefill: const WishPrefillData(linkUrl: 'https://shop.fr/b'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AddWishScreen), findsOneWidget);
    expect(
      container.read(shareIntentPayloadNotifierProvider),
      const ShareIntentPayload(),
      reason: 'le 2e partage doit être consommé, pas laissé en attente',
    );
  });
}
