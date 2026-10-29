import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_repository.dart';
import 'package:wishlist/shared/infra/utils/execute_safely.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/models/received_wishes_summary/received_wishes_summary.dart';
import 'package:wishlist/shared/models/wish/wish.dart';

class SupabaseUserCompletedWishRepository
    implements UserCompletedWishRepository {
  SupabaseUserCompletedWishRepository(this._client);

  final SupabaseClient _client;
  static const _tableName = 'user_completed_wishs';
  static const _wishTakenByUserTableName = 'wish_taken_by_user';

  /// completed_at is a date column: a day, without time or time zone.
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  /// Updates the completed wish [wishId] of [userId]. An UPDATE that matches
  /// no row is not an error for PostgREST: a row gone meanwhile (uncompleted
  /// on another device) throws, rather than passing for a success.
  Future<void> _updateRow({
    required String userId,
    required int wishId,
    required Map<String, Object> values,
  }) async {
    final updated = await _client
        .from(_tableName)
        .update(values)
        .eq('user_id', userId)
        .eq('wish_id', wishId)
        .select('wish_id');
    if (updated.isEmpty) {
      throw AppException(statusCode: 404, message: 'Completed wish not found');
    }
  }

  @override
  Future<void> markAsCompleted({
    required String userId,
    required int wishId,
    required int fromWishlistId,
    required int quantity,
    required DateTime completedAt,
  }) async {
    return executeSafely(
      () async {
        final existing = await _client
            .from(_tableName)
            .select('quantity, completed_at')
            .eq('user_id', userId)
            .eq('wish_id', wishId)
            .maybeSingle();

        if (existing != null) {
          final newQuantity = (existing['quantity'] as num).toInt() + quantity;
          final existingCompletedAt =
              DateTime.parse(existing['completed_at'] as String);
          final newCompletedAt = completedAt.isAfter(existingCompletedAt)
              ? completedAt
              : existingCompletedAt;
          await _updateRow(
            userId: userId,
            wishId: wishId,
            values: {
              'quantity': newQuantity,
              'completed_at': _dateFormat.format(newCompletedAt),
            },
          );
        } else {
          await _client.from(_tableName).insert({
            'user_id': userId,
            'wish_id': wishId,
            'from_wishlist_id': fromWishlistId,
            'quantity': quantity,
            'completed_at': _dateFormat.format(completedAt),
          });
        }
      },
      errorMessage: 'Failed to mark wish as completed',
    );
  }

  @override
  Future<void> updateCompletedWishQuantity({
    required String userId,
    required int wishId,
    required int newQuantity,
  }) async {
    return executeSafely(
      () async {
        await _updateRow(
          userId: userId,
          wishId: wishId,
          values: {'quantity': newQuantity},
        );
      },
      errorMessage: 'Failed to update completed wish quantity',
    );
  }

  @override
  Future<void> updateCompletionDate({
    required String userId,
    required int wishId,
    required DateTime completedAt,
  }) async {
    return executeSafely(
      () async {
        await _updateRow(
          userId: userId,
          wishId: wishId,
          values: {'completed_at': _dateFormat.format(completedAt)},
        );
      },
      errorMessage: 'Failed to update completion date',
    );
  }

  @override
  Future<void> unmarkAsCompleted({
    required String userId,
    required int wishId,
  }) async {
    return executeSafely(
      () async {
        await _client
            .from(_tableName)
            .delete()
            .eq('user_id', userId)
            .eq('wish_id', wishId);
      },
      errorMessage: 'Failed to unmark wish as completed',
    );
  }

  @override
  Future<void> restoreCompletedWish({
    required int wishId,
    required int targetWishlistId,
  }) async {
    return executeSafely(
      () async {
        await _client.rpc(
          'restore_completed_wish',
          params: {
            'p_wish_id': wishId,
            'p_target_wishlist_id': targetWishlistId,
          },
        );
      },
      errorMessage: 'Failed to restore completed wish',
    );
  }

  @override
  Future<IList<CompletedWishWithDetails>> getCompletedWishesByUser(
    String userId,
  ) async {
    return executeSafely(
      () async {
        final response = await _client
            .from(_tableName)
            .select('''
               completed_at,
               quantity,
               wishs!inner(
                 *,
                 wishlist:wishlists!inner(
                   name,
                   deleted_at,
                   id_owner,
                   profiles!inner(
                     pseudo,
                     avatar_url
                   )
                 ),
                 taken_by_user:$_wishTakenByUserTableName(*)
               )
            ''')
            .eq('user_id', userId)
            // Several wishes received the same day: the last one first
            // completed first (completing more of a wish later does not
            // change created_at)
            .order('completed_at', ascending: false)
            .order('created_at', ascending: false);

        return response.map((item) {
          final wishData = item['wishs'] as Map<String, dynamic>;
          final wishlistData = wishData['wishlist'] as Map<String, dynamic>;
          final profileData = wishlistData['profiles'] as Map<String, dynamic>;

          return CompletedWishWithDetails(
            wish: Wish.fromJson(wishData),
            fromWishlistId: wishData['wishlist_id'] as int,
            fromWishlistName: wishlistData['deleted_at'] == null
                ? wishlistData['name'] as String
                : CompletedWishWithDetails.deletedWishlistName,
            ownerId: wishlistData['id_owner'] as String,
            ownerPseudo: profileData['pseudo'] as String,
            ownerAvatarUrl: profileData['avatar_url'] as String?,
            // A day ('2026-10-29'): parsed as local midnight
            completedAt: DateTime.parse(item['completed_at'] as String),
            quantity: (item['quantity'] as num).toInt(),
          );
        }).toIList();
      },
      errorMessage: 'Failed to get completed wishes by user',
    );
  }

  @override
  Future<ReceivedWishesSummary> getReceivedWishesSummary(String userId) async {
    return executeSafely(
      () async {
        // The same inner joins as [getCompletedWishesByUser], on their ids
        // only: the rows that are counted are the ones the list shows.
        final response = await _client.from(_tableName).select('''
               completed_at,
               wishs!inner(
                 id,
                 wishlist:wishlists!inner(
                   id,
                   profiles!inner(id)
                 )
               )
            ''').eq('user_id', userId).order('completed_at', ascending: false);

        return ReceivedWishesSummary(
          count: response.length,
          // A day ('2026-10-29'): parsed as local midnight
          latestCompletedAt: response.isEmpty
              ? null
              : DateTime.parse(response.first['completed_at'] as String),
        );
      },
      errorMessage: 'Failed to get received wishes summary',
    );
  }
}
