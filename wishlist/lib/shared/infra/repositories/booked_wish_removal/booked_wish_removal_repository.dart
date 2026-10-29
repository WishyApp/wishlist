import 'package:wishlist/shared/models/booked_wish_removal.dart';

abstract class BookedWishRemovalRepository {
  /// Alerts of the current user that are not dismissed yet, most recent first.
  /// Reloaded on every insert or update of their rows, and after each
  /// (re)subscription of the Realtime channel.
  Stream<List<BookedWishRemoval>> watchPending();

  /// Closes the alert [id] (sets `dismissed_at`).
  Future<void> dismiss(int id);

  /// Releases the Realtime channel and the streams.
  Future<void> dispose();
}
