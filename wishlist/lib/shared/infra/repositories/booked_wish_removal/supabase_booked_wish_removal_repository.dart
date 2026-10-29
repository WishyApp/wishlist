import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/keyed_realtime_streams.dart';
import 'package:wishlist/shared/infra/non_null_extensions/go_true_client_non_null_getter_user_extension.dart';
import 'package:wishlist/shared/infra/repositories/booked_wish_removal/booked_wish_removal_repository.dart';
import 'package:wishlist/shared/infra/utils/execute_safely.dart';
import 'package:wishlist/shared/models/booked_wish_removal.dart';

class SupabaseBookedWishRemovalRepository
    implements BookedWishRemovalRepository {
  SupabaseBookedWishRemovalRepository(this._client);

  final SupabaseClient _client;
  static const _tableName = 'booked_wish_removals';

  late final _streams = KeyedRealtimeStreams(
    logTag: 'booked_wish_removals',
    isSocketConnected: () => _client.realtime.isConnected,
  );

  /// Builds, without subscribing it, a channel on the rows of
  /// `booked_wish_removals` booked by [userId].
  ///
  /// Every event reloads: INSERT (a trigger recorded a removal), UPDATE (the
  /// alert was dismissed from another device) and DELETE (the owner deleted
  /// their account, which cascades the alerts away). The filter reduces
  /// traffic, it is not an access barrier: Realtime applies the SELECT policy
  /// of the table.
  /// A change committed between the first load and the subscription is never
  /// delivered: [KeyedRealtimeStreams] reloads once the channel is subscribed
  /// (and on every reconnection).
  RealtimeChannel _buildChannel(String userId, void Function() onChange) {
    return _client.channel('booked_wish_removals_$userId').onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _tableName,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'booker_id',
            value: userId,
          ),
          callback: (payload) => onChange(),
        );
  }

  Future<List<BookedWishRemoval>> _fetchPending() {
    return executeSafely(
      () async {
        // The RLS keeps the rows of the current user.
        final rows = await _client
            .from(_tableName)
            .select()
            .isFilter('dismissed_at', null)
            .order('removed_at', ascending: false);
        return rows.map(BookedWishRemoval.fromRow).toList();
      },
      errorMessage: 'Failed to load the removed booked wishes',
    );
  }

  @override
  Stream<List<BookedWishRemoval>> watchPending() {
    final currentUserId = _client.auth.currentUserNonNull.id;

    return _streams.watch<List<BookedWishRemoval>>(
      'pending_$currentUserId',
      load: _fetchPending,
      channelBuilder: (reload) => _buildChannel(currentUserId, reload),
    );
  }

  @override
  Future<void> dismiss(int id) {
    return executeSafely(
      () async {
        await _client.from(_tableName).update({
          'dismissed_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', id);
      },
      errorMessage: 'Failed to dismiss the removed booked wish',
    );
  }

  @override
  Future<void> dispose() => _streams.dispose();
}
