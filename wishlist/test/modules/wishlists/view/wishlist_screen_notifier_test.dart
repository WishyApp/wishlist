import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/modules/wishlists/infra/wishlist_screen_data_realtime_provider.dart';
import 'package:wishlist/modules/wishlists/view/wishlist_screen_notifier.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_repository.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_repository_provider.dart';
import 'package:wishlist/shared/models/wish/wish.dart';

import '../../../fixtures/fake_data.dart';

class MockWishRepository extends Mock implements WishRepository {}

Wish wishWith(int id, String iconUrl) => Wish(
      id: id,
      createdAt: fakeCreatedAt,
      name: 'wish $id',
      description: '',
      wishlistId: 1,
      quantity: 1,
      iconUrl: iconUrl,
      updatedBy: fakeCurrentUserId,
      updatedAt: fakeUpdatedAt,
    );

void main() {
  group('WishlistScreenNotifier.deleteSelectedWishs', () {
    late MockWishRepository repository;

    ProviderContainer buildContainer(List<Wish> loadedWishs) {
      final container = ProviderContainer(
        overrides: [
          wishRepositoryProvider.overrideWithValue(repository),
          wishlistScreenDataRealtimeProvider(1).overrideWithValue(
            AsyncData((fakeWishlist1, IList<Wish>(loadedWishs), IList())),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      repository = MockWishRepository();
      when(() => repository.deleteWishImage(any())).thenAnswer((_) async {});
      when(() => repository.deleteWish(any())).thenAnswer((_) async {});
    });

    test('removes the image and thumbnail of each selected wish', () async {
      final container = buildContainer([
        wishWith(1, 'user-1/1/wish_image_1.webp'),
        // Legacy layout, and a wish without image.
        wishWith(2, '2/wish_image_2.webp'),
        wishWith(3, ''),
      ]);

      final notifier =
          container.read(wishlistScreenNotifierProvider(1).notifier)
            ..enableSelectionMode(1)
            ..toggleWishSelection(2)
            ..toggleWishSelection(3);

      await notifier.deleteSelectedWishs();

      final removed = verify(
        () => repository.deleteWishImage(captureAny()),
      ).captured;
      expect(
        removed,
        unorderedEquals([
          'user-1/1/wish_image_1.webp',
          'user-1/1/wish_image_1_thumb.webp',
          '2/wish_image_2.webp',
          '2/wish_image_2_thumb.webp',
        ]),
      );
      for (final id in [1, 2, 3]) {
        verify(() => repository.deleteWish(id)).called(1);
      }
      verifyNever(() => repository.getWishById(any()));
    });

    test('keeps deleting when a selected wish is no longer loaded', () async {
      final container = buildContainer([
        wishWith(1, 'user-1/1/wish_image_1.webp'),
        wishWith(3, 'user-1/3/wish_image_3.webp'),
      ]);

      final provider = wishlistScreenNotifierProvider(1);
      final notifier = container.read(provider.notifier)
        ..enableSelectionMode(1)
        ..toggleWishSelection(2) // deleted from another device
        ..toggleWishSelection(3);

      await notifier.deleteSelectedWishs();

      final removed = verify(
        () => repository.deleteWishImage(captureAny()),
      ).captured;
      expect(
        removed,
        unorderedEquals([
          'user-1/1/wish_image_1.webp',
          'user-1/1/wish_image_1_thumb.webp',
          'user-1/3/wish_image_3.webp',
          'user-1/3/wish_image_3_thumb.webp',
        ]),
      );
      for (final id in [1, 2, 3]) {
        verify(() => repository.deleteWish(id)).called(1);
      }
      verifyNever(() => repository.getWishById(any()));
      expect(container.read(provider).isSelectionMode, isFalse);
    });
  });
}
