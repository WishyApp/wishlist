import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/modules/wishlists/infra/wishlist_screen_data_realtime_provider.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_stream_repository.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_stream_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_stream_repository.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_stream_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_stream_repository.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_stream_repository_provider.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_streams_providers.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';
import 'package:wishlist/shared/theme/providers/wishlist_theme_provider.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/mock_supabase.dart';

class _MockWishlistStreamRepository extends Mock
    implements WishlistStreamRepository {}

class _MockWishStreamRepository extends Mock implements WishStreamRepository {}

class _MockCompletedWishStreamRepository extends Mock
    implements UserCompletedWishStreamRepository {}

/// Wishlist-bound providers are keyed by wishlist id, not by user: they must
/// not outlive the screens using them, or a later session would be served the
/// previous one's cached wishlist and channels (F015).
void main() {
  late FakeAuthSession session;
  late ProviderContainer container;

  setUp(() {
    session = FakeAuthSession(userId: 'user-a');
    addTearDown(session.close);
    final wishlistRepository = _MockWishlistStreamRepository();
    when(() => wishlistRepository.watchWishlistById(any()))
        .thenAnswer((_) => Stream.value(fakeWishlist1));
    final wishRepository = _MockWishStreamRepository();
    when(() => wishRepository.watchWishsFromWishlist(any()))
        .thenAnswer((_) => Stream.value(const IListConst([])));
    final completedRepository = _MockCompletedWishStreamRepository();
    when(() => completedRepository.watchCompletedWishesByUser(any()))
        .thenAnswer((_) => Stream.value(const IListConst([])));
    container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(session.client),
        wishlistStreamRepositoryProvider.overrideWithValue(wishlistRepository),
        wishStreamRepositoryProvider.overrideWithValue(wishRepository),
        userCompletedWishStreamRepositoryProvider
            .overrideWithValue(completedRepository),
      ],
    );
    addTearDown(container.dispose);
  });

  test('wishlistScreenDataRealtimeProvider releases its streams when unused',
      () async {
    final subscription = container.listen(
      wishlistScreenDataRealtimeProvider(1),
      (_, __) {},
    );
    await pumpEventQueue();
    expect(subscription.read().hasValue, isTrue);

    subscription.close();
    await pumpEventQueue();

    expect(container.exists(wishlistScreenDataRealtimeProvider(1)), isFalse);
    expect(container.exists(watchWishlistByIdProvider(1)), isFalse);
  });

  test('wishlistThemeProvider releases its stream when unused', () async {
    final subscription = container.listen(wishlistThemeProvider(1), (_, __) {});
    await pumpEventQueue();
    expect(subscription.read().hasValue, isTrue);

    subscription.close();
    await pumpEventQueue();

    expect(container.exists(wishlistThemeProvider(1)), isFalse);
    expect(container.exists(watchWishlistByIdProvider(1)), isFalse);
  });

  test('wishlistThemeCacheProvider is reset when the user changes', () async {
    container.listen(wishlistThemeCacheProvider(1), (_, __) {});
    container.read(wishlistThemeCacheProvider(1).notifier).state = ThemeData();

    session
      ..signOut()
      ..signIn('user-b');
    await pumpEventQueue();

    expect(container.read(wishlistThemeCacheProvider(1)), isNull);
  });
}
