import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/shared/infra/friendship_mutations_provider.dart';
import 'package:wishlist/shared/infra/friendship_service.dart';
import 'package:wishlist/shared/infra/wish_mutations_provider.dart';
import 'package:wishlist/shared/infra/wish_service.dart';
import 'package:wishlist/shared/infra/wishlist_mutations_provider.dart';
import 'package:wishlist/shared/infra/wishlist_service.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/models/wishlist/create_request/wishlist_create_request.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';

class MockWishService extends Mock implements WishService {}

class MockWishlistService extends Mock implements WishlistService {}

class MockFriendshipService extends Mock implements FriendshipService {}

class FakeWish extends Fake implements Wish {}

class FakeWishlist extends Fake implements Wishlist {}

class FakeWishlistCreateRequest extends Fake implements WishlistCreateRequest {}

void main() {
  final error = Exception('network down');

  setUpAll(() {
    registerFallbackValue(FakeWish());
    registerFallbackValue(FakeWishlist());
    registerFallbackValue(FakeWishlistCreateRequest());
  });

  test('WishMutations rethrows the service error', () async {
    final service = MockWishService();
    when(() => service.updateWish(any())).thenThrow(error);
    final container = ProviderContainer(
      overrides: [wishServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.listen(wishMutationsProvider, (_, __) {});

    await expectLater(
      container.read(wishMutationsProvider.notifier).update(FakeWish()),
      throwsA(error),
    );
    expect(container.read(wishMutationsProvider).isError, isTrue);
  });

  group('WishlistMutations rethrows the service error', () {
    late MockWishlistService service;
    late ProviderContainer container;

    setUp(() {
      service = MockWishlistService();
      when(() => service.createWishlist(any())).thenThrow(error);
      when(() => service.updateWishlist(any())).thenThrow(error);
      when(() => service.deleteWishlist(any())).thenThrow(error);
      container = ProviderContainer(
        overrides: [wishlistServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      container.listen(wishlistMutationsProvider, (_, __) {});
    });

    final calls = <String, Future<void> Function(WishlistMutations)>{
      'create': (m) => m.create(FakeWishlistCreateRequest()),
      'update': (m) => m.update(FakeWishlist()),
      'delete': (m) => m.delete(1),
    };

    for (final MapEntry(key: name, value: call) in calls.entries) {
      test(name, () async {
        await expectLater(
          call(container.read(wishlistMutationsProvider.notifier)),
          throwsA(error),
        );
        expect(container.read(wishlistMutationsProvider).isError, isTrue);
      });
    }
  });

  group('FriendshipMutations rethrows the service error', () {
    late MockFriendshipService service;
    late ProviderContainer container;

    setUp(() {
      service = MockFriendshipService();
      when(() => service.askFriendshipTo(any())).thenThrow(error);
      when(() => service.cancelFriendshipRequest(any())).thenThrow(error);
      when(() => service.acceptFriendshipWith(any())).thenThrow(error);
      when(() => service.declineFriendshipWith(any())).thenThrow(error);
      when(() => service.removeFriendshipWith(any())).thenThrow(error);
      container = ProviderContainer(
        overrides: [friendshipServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      container.listen(friendshipMutationsProvider, (_, __) {});
    });

    final calls = <String, Future<void> Function(FriendshipMutations)>{
      'askFriendship': (m) => m.askFriendship('u'),
      'cancelFriendshipRequest': (m) => m.cancelFriendshipRequest('u'),
      'acceptFriendship': (m) => m.acceptFriendship('u'),
      'declineFriendship': (m) => m.declineFriendship('u'),
      'removeFriendship': (m) => m.removeFriendship('u'),
    };

    for (final MapEntry(key: name, value: call) in calls.entries) {
      test(name, () async {
        await expectLater(
          call(container.read(friendshipMutationsProvider.notifier)),
          throwsA(error),
        );
        expect(container.read(friendshipMutationsProvider).isError, isTrue);
      });
    }
  });
}
