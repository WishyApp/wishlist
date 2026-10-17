import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/modules/wishlists/view/wishlist_screen_notifier.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_repository.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_repository_provider.dart';

import '../../../fixtures/fake_data.dart';

class MockWishRepository extends Mock implements WishRepository {}

void main() {
  group('WishlistScreenNotifier.deleteSelectedWishs', () {
    late MockWishRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = MockWishRepository();
      container = ProviderContainer(
        overrides: [wishRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      when(() => repository.deleteWishImage(any())).thenAnswer((_) async {});
      when(() => repository.deleteWish(any())).thenAnswer((_) async {});
    });

    test('removes the image and thumbnail of each selected wish', () async {
      when(() => repository.getWishById(1)).thenAnswer(
        (_) async => fakeWish1.copyWith(iconUrl: 'user-1/1/wish_image_1.webp'),
      );
      // Legacy layout, and a wish without image.
      when(() => repository.getWishById(2)).thenAnswer(
        (_) async => fakeWish2.copyWith(iconUrl: '2/wish_image_2.webp'),
      );
      when(() => repository.getWishById(3)).thenAnswer(
        (_) async => fakeWish1,
      );

      final provider = wishlistScreenNotifierProvider(1);
      final notifier = container.read(provider.notifier)
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
    });
  });
}
