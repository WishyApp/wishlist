import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_repository.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_repository_provider.dart';
import 'package:wishlist/shared/models/booked_wish_with_details/booked_wish_with_details.dart';

class BookedWishesNotifier
    extends StateNotifier<AsyncValue<IList<BookedWishWithDetails>>> {
  BookedWishesNotifier(this._wishRepository, {required String? userId})
      : _userId = userId,
        super(const AsyncValue.loading()) {
    loadBookedWishes();
  }

  final WishRepository _wishRepository;
  // Null while signed out: stays loading, nothing to fetch.
  final String? _userId;

  Future<void> loadBookedWishes() async {
    final userId = _userId;
    state = const AsyncValue.loading();
    if (userId == null) {
      return;
    }
    try {
      final bookedWishes = await _wishRepository.getBookedWishesByUser(userId);
      state = AsyncValue.data(bookedWishes);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final bookedWishesProvider = StateNotifierProvider.autoDispose<
    BookedWishesNotifier, AsyncValue<IList<BookedWishWithDetails>>>((ref) {
  // Rebuilt (and reloaded) when the user changes.
  return BookedWishesNotifier(
    ref.watch(wishRepositoryProvider),
    userId: ref.watch(currentUserIdProvider),
  );
});
