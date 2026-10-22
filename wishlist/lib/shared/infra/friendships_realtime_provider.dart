import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/repositories/friendship/friendship_stream_repository.dart';
import 'package:wishlist/shared/infra/repositories/friendship/friendship_stream_repository_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/models/app_user.dart';
import 'package:wishlist/shared/utils/first_event_timeout.dart';

final friendshipsRealtimeProvider =
    StreamProvider.autoDispose<FriendsData>((ref) {
  // Rebuilt on logout / user switch: the widgets listening to it (the nav bar)
  // can outlive a session. Signed out, it emits an empty value (which replaces
  // the previous user's one) instead of reading the repository without a user.
  if (ref.watch(currentUserIdProvider) == null) {
    return Stream.value(
      const FriendsData(
        friends: IListConst([]),
        pendingFriends: IListConst([]),
        requestedFriends: IListConst([]),
      ),
    );
  }

  final userService = ref.watch(userServiceProvider);
  final friendshipRepo = ref.watch(friendshipStreamRepositoryProvider);

  final allFriendshipsStream = friendshipRepo.watchCurrentUserAllFriendships();

  // Per build: reset when the provider rebuilds (user switch, invalidate).
  FriendsData? lastData;

  return allFriendshipsStream.asyncMap((friendshipIds) async {
    try {
      return lastData = await _loadFriendsData(userService, friendshipIds);
    } catch (e) {
      final previous = lastData;
      // First load: surface the error so the screen can report it.
      if (previous == null) {
        rethrow;
      }
      // Later reloads: a transient failure must not replace the data already
      // displayed (nor make the dependent widgets disappear).
      debugPrint(
        '[Wishy friends] profiles reload failed, keeping last value: $e',
      );
      return previous;
    }
  }).timeoutFirstEvent();
});

Future<FriendsData> _loadFriendsData(
  UserService userService,
  FriendshipIds friendshipIds,
) async {
  final results = await Future.wait([
    _loadUsersFromIds(userService, friendshipIds.friendsIds),
    _loadUsersFromIds(userService, friendshipIds.pendingIds),
    _loadUsersFromIds(userService, friendshipIds.requestedIds),
  ]);

  return FriendsData(
    friends: results[0],
    pendingFriends: results[1],
    requestedFriends: results[2],
  );
}

Future<IList<AppUser>> _loadUsersFromIds(
  UserService userService,
  ISet<String> userIds,
) async {
  if (userIds.isEmpty) {
    return const IListConst([]);
  }

  final users = await Future.wait(
    userIds.map((userId) => _loadUserOrNull(userService, userId)),
  );
  return users.nonNulls.toIList();
}

/// A friendship can point to a profile the users_profiles view does not
/// return (no pseudo yet, hidden by RLS): `.single()` then finds no row
/// (PGRST116) and that user is skipped. Any other failure (network, server)
/// propagates so the screen shows its error state instead of an empty list.
Future<AppUser?> _loadUserOrNull(UserService userService, String userId) async {
  try {
    return await userService.getAppUserById(userId);
  } on AppException catch (e) {
    final cause = e.cause;
    if (cause is PostgrestException && cause.code == _noRowCode) {
      return null;
    }
    rethrow;
  }
}

const _noRowCode = 'PGRST116';

class FriendsData {
  const FriendsData({
    required this.friends,
    required this.pendingFriends,
    required this.requestedFriends,
  });

  final IList<AppUser> friends;
  final IList<AppUser> pendingFriends;
  final IList<AppUser> requestedFriends;

  bool get isEmpty =>
      friends.isEmpty && pendingFriends.isEmpty && requestedFriends.isEmpty;

  int get totalCount =>
      friends.length + pendingFriends.length + requestedFriends.length;

  FriendsData copyWith({
    IList<AppUser>? friends,
    IList<AppUser>? pendingFriends,
    IList<AppUser>? requestedFriends,
  }) {
    return FriendsData(
      friends: friends ?? this.friends,
      pendingFriends: pendingFriends ?? this.pendingFriends,
      requestedFriends: requestedFriends ?? this.requestedFriends,
    );
  }
}
