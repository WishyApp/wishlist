import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/modules/wishlists/infra/wishlist_screen_data_realtime_provider.dart';
import 'package:wishlist/modules/wishlists/view/wishlist_screen_notifier.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_repository.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_repository_provider.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/models/wish/wish_sort_type.dart';
import 'package:wishlist/shared/theme/providers/wishlist_theme_provider.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/mock_supabase.dart';

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
          wishlistThemeCacheProvider(1).overrideWith((ref) => null),
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

  group('WishlistScreenNotifier selection', () {
    late ProviderContainer container;
    final provider = wishlistScreenNotifierProvider(1);

    WishlistScreenState state() => container.read(provider);
    WishlistScreenNotifier notifier() => container.read(provider.notifier);

    setUp(() {
      container = ProviderContainer(
        overrides: [
          wishlistThemeCacheProvider(1).overrideWith((ref) => null),
          wishlistScreenDataRealtimeProvider(1).overrideWithValue(
            AsyncData((fakeWishlist1, IList<Wish>(), IList())),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(provider, (_, __) {});
      addTearDown(sub.close);
    });

    test('selectAll adds the visible wishes to the current selection', () {
      notifier()
        ..enableSelectionMode(1)
        ..selectAll([2, 3]);

      expect(state().selectedWishIds, {1, 2, 3});
      expect(state().isSelectionMode, isTrue);
    });

    test('selectAll enters selection mode and ignores an empty list', () {
      notifier().selectAll([]);
      expect(state().isSelectionMode, isFalse);

      notifier().selectAll([4, 5]);
      expect(state().selectedWishIds, {4, 5});
      expect(state().isSelectionMode, isTrue);
    });

    test('deselectAll keeps the wishes hidden by the search', () {
      notifier()
        ..enableSelectionMode(1)
        ..toggleWishSelection(2)
        ..toggleWishSelection(3)
        ..deselectAll([2, 3]);

      expect(state().selectedWishIds, {1});
      expect(state().isSelectionMode, isTrue);
    });

    test('deselectAll exits selection mode once nothing is selected', () {
      notifier()
        ..enableSelectionMode(1)
        ..toggleWishSelection(2)
        ..deselectAll([1, 2]);

      expect(state().selectedWishIds, isEmpty);
      expect(state().isSelectionMode, isFalse);
    });

    test('keeps the selection when the search or the sort change', () {
      notifier()
        ..enableSelectionMode(1)
        ..toggleWishSelection(2)
        ..updateSort(
          const WishSort(
            type: WishSortType.price,
            order: SortOrder.ascending,
          ),
        );
      notifier().searchController.text = 'Wulfgar';

      expect(state().searchQuery, 'wulfgar');
      expect(state().selectedWishIds, {1, 2});
      expect(state().isSelectionMode, isTrue);
    });

    test('areAllSelected is true only when every visible wish is selected', () {
      notifier()
        ..enableSelectionMode(1)
        ..toggleWishSelection(2);

      expect(state().areAllSelected([1, 2]), isTrue);
      expect(state().areAllSelected([2]), isTrue);
      expect(state().areAllSelected([1, 2, 3]), isFalse);
      // Nothing displayed: nothing to deselect
      expect(state().areAllSelected([]), isFalse);
    });
  });

  group('WishlistScreenNotifier keeps the selection in the listed wishs', () {
    late ProviderContainer container;
    late StateController<AsyncValue<WishlistScreenData>> data;
    late MockWishRepository repository;
    final provider = wishlistScreenNotifierProvider(1);
    final wishs = [for (var id = 1; id <= 3; id++) wishWith(id, '')];

    CompletedWishWithDetails received(Wish wish, int quantity) =>
        CompletedWishWithDetails(
          wish: wish,
          fromWishlistId: wish.wishlistId,
          fromWishlistName: fakeWishlist1.name,
          ownerPseudo: 'owner',
          ownerId: fakeCurrentUserId,
          completedAt: fakeCreatedAt,
          quantity: quantity,
        );

    void emit(
      List<Wish> listed, [
      List<CompletedWishWithDetails> completed = const [],
    ]) =>
        data.state = AsyncData(
          (fakeWishlist1, IList<Wish>(listed), IList(completed)),
        );

    setUp(() {
      final dataProvider = StateProvider<AsyncValue<WishlistScreenData>>(
        (ref) => AsyncData((fakeWishlist1, IList<Wish>(wishs), IList())),
      );
      repository = MockWishRepository();
      when(() => repository.deleteWish(any())).thenAnswer((_) async {});
      container = ProviderContainer(
        overrides: [
          wishRepositoryProvider.overrideWithValue(repository),
          wishlistThemeCacheProvider(1).overrideWith((ref) => null),
          wishlistScreenDataRealtimeProvider(1)
              .overrideWith((ref) => ref.watch(dataProvider)),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(provider, (_, __) {});
      addTearDown(sub.close);
      data = container.read(dataProvider.notifier);
      container.read(provider.notifier)
        ..enableSelectionMode(1)
        ..toggleWishSelection(2);
    });

    test('drops a selected wish deleted or moved elsewhere', () {
      emit([wishs[1], wishs[2]]);

      expect(container.read(provider).selectedWishIds, {2});
      expect(container.read(provider).isSelectionMode, isTrue);
    });

    test('drops a selected wish fully received', () {
      emit(wishs, [received(wishs[0], 1)]);

      expect(container.read(provider).selectedWishIds, {2});
    });

    test('exits selection mode once no selected wish is listed', () {
      emit([wishs[2]]);

      expect(container.read(provider).selectedWishIds, isEmpty);
      expect(container.read(provider).isSelectionMode, isFalse);
    });

    test('keeps the selection while its wishs are listed', () {
      final before = container.read(provider);

      emit([...wishs, wishWith(4, '')]);

      expect(identical(container.read(provider), before), isTrue);
    });

    test('keeps the selection until the end of an action on it', () async {
      final notifier = container.read(provider.notifier);
      WishlistScreenState? during;

      final count = await notifier.runOnSelection((wishIds) async {
        // The wishs leave the list one by one as the action handles them
        emit([wishs[1], wishs[2]]);
        emit([wishs[2]]);
        during = container.read(provider);
      });

      expect(count, 2);
      expect(during!.selectedWishIds, {1, 2});
      expect(during!.isSelectionMode, isTrue);
      expect(container.read(provider).isSelectionMode, isFalse);
      expect(container.read(provider).selectedWishIds, isEmpty);
    });

    test('keeps the wishs still listed when an action fails', () async {
      final notifier = container.read(provider.notifier);

      await expectLater(
        notifier.runOnSelection((wishIds) async {
          emit([wishs[1], wishs[2]]);
          throw Exception('network');
        }),
        throwsException,
      );

      expect(container.read(provider).selectedWishIds, {2});
      expect(container.read(provider).isSelectionMode, isTrue);
    });

    test('deletes, and counts, the wishs selected when it runs', () async {
      container.read(provider.notifier).toggleWishSelection(3);
      // Wish 3 deleted from another device while the confirmation is open
      emit([wishs[0], wishs[1]]);

      final deleted =
          await container.read(provider.notifier).deleteSelectedWishs();

      expect(deleted, 2);
      verify(() => repository.deleteWish(1)).called(1);
      verify(() => repository.deleteWish(2)).called(1);
      verifyNever(() => repository.deleteWish(3));
    });

    test('runs nothing on an empty selection', () async {
      container.read(provider.notifier).exitSelectionMode();
      var runs = 0;

      final count = await container
          .read(provider.notifier)
          .runOnSelection((_) async => runs++);

      expect(count, 0);
      expect(runs, 0);
    });
  });

  testWidgets('cacheWishlistTheme writes only when the theme changes',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(createMockSupabaseClient()),
        wishlistScreenDataRealtimeProvider(2).overrideWithValue(
          const AsyncLoading(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(wishlistScreenNotifierProvider(2), (_, __) {});
    addTearDown(sub.close);
    final notifier = container.read(wishlistScreenNotifierProvider(2).notifier);

    // StateController notifies on every write from another instance
    var writes = 0;
    container.listen(wishlistThemeCacheProvider(2), (_, __) => writes++);

    notifier.cacheWishlistTheme(2, ThemeData.light());
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(writes, 1);

    // A value-equal theme (another instance) is not written again
    notifier.cacheWishlistTheme(2, ThemeData.light());
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(writes, 1);

    notifier.cacheWishlistTheme(2, ThemeData.dark());
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(writes, 2);
  });
}
