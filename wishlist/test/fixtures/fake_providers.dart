import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/app_info_provider.dart';
import 'package:wishlist/shared/infra/booked_wishes_realtime_provider.dart';
import 'package:wishlist/shared/infra/clock_provider.dart';
import 'package:wishlist/shared/infra/completed_wishes_realtime_provider.dart';
import 'package:wishlist/shared/infra/current_user_birthday_provider.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/current_user_profile_provider.dart';
import 'package:wishlist/shared/infra/friend_details_realtime_provider.dart';
import 'package:wishlist/shared/infra/friendships_realtime_provider.dart';
import 'package:wishlist/shared/infra/repositories/user/user_streams_providers.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_streams_providers.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_streams_providers.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/infra/visible_birthdays_provider.dart';
import 'package:wishlist/shared/infra/wishlists_realtime_provider.dart';
import 'package:wishlist/shared/models/app_user.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/models/booked_wish_with_details/booked_wish_with_details.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/models/friend_details/friend_details.dart';
import 'package:wishlist/shared/models/profile.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';

import 'fake_data.dart';
import 'mock_supabase.dart';

// =============================================================================
// SUPABASE PROVIDER OVERRIDE
// =============================================================================

/// Override pour supabaseClientProvider avec un mock
Override supabaseClientOverride({
  String? userId,
  String? userEmail,
  bool signedOut = false,
  List<String> authProviders = const ['email'],
}) {
  return supabaseClientProvider.overrideWithValue(
    createMockSupabaseClient(
      userId: userId,
      userEmail: userEmail,
      signedOut: signedOut,
      authProviders: authProviders,
    ),
  );
}

// =============================================================================
// WISHLISTS PROVIDER OVERRIDES
// =============================================================================

/// Override pour wishlistsRealtimeProvider avec des wishlists de test
Override wishlistsRealtimeOverride({
  List<Wishlist>? wishlists,
}) {
  return wishlistsRealtimeProvider.overrideWith(
    (ref) => Stream.value(wishlists ?? fakeWishlists),
  );
}

/// Override pour wishlistsRealtimeProvider avec une liste vide
Override emptyWishlistsRealtimeOverride() {
  return wishlistsRealtimeProvider.overrideWith(
    (ref) => Stream.value(<Wishlist>[]),
  );
}

// =============================================================================
// FRIENDS PROVIDER OVERRIDES
// =============================================================================

/// Override pour friendshipsRealtimeProvider avec des amis de test
Override friendshipsRealtimeOverride({
  FriendsData? friendsData,
}) {
  return friendshipsRealtimeProvider.overrideWith(
    (ref) => Stream.value(friendsData ?? fakeFriendsData),
  );
}

/// Override pour friendshipsRealtimeProvider avec une liste vide
Override emptyFriendshipsRealtimeOverride() {
  return friendshipsRealtimeProvider.overrideWith(
    (ref) => Stream.value(fakeEmptyFriendsData),
  );
}

// =============================================================================
// BOOKED WISHES PROVIDER OVERRIDES
// =============================================================================

/// Override pour bookedWishesRealtimeProvider avec des wishes réservés de test
Override bookedWishesRealtimeOverride({
  IList<BookedWishWithDetails>? bookedWishes,
}) {
  return bookedWishesRealtimeProvider.overrideWith(
    (ref) => Stream.value(bookedWishes ?? fakeBookedWishes),
  );
}

/// Override pour bookedWishesRealtimeProvider avec une liste vide
Override emptyBookedWishesRealtimeOverride() {
  return bookedWishesRealtimeProvider.overrideWith(
    (ref) => Stream.value(fakeEmptyBookedWishes),
  );
}

// =============================================================================
// USER SERVICE OVERRIDE
// =============================================================================

/// Override pour userServiceProvider avec un mock
Override userServiceOverride({String? userId}) {
  return userServiceProvider.overrideWithValue(
    createMockUserService(userId: userId),
  );
}

// =============================================================================
// PROFILE STREAM OVERRIDE
// =============================================================================

/// Override pour watchCurrentUserProfileProvider avec un profil de test
Override watchCurrentUserProfileOverride({Profile? profile}) {
  return watchCurrentUserProfileProvider.overrideWith(
    (ref) => Stream.value(profile ?? fakeCurrentUserProfile),
  );
}

// =============================================================================
// APP INFO OVERRIDE
// =============================================================================

/// Override pour appInfoProvider avec des infos de test
Override appInfoOverride() {
  return appInfoProvider.overrideWith((ref) async => fakePackageInfo);
}

// =============================================================================
// COMBINED OVERRIDES FOR SCREENS
// =============================================================================

/// Overrides pour le HomeScreen (tab home de FloatingNavBarNavigator)
List<Override> homeScreenOverrides({
  List<Wishlist>? wishlists,
  FriendsData? friendsData,
  IList<BookedWishWithDetails>? bookedWishes,
  String? currentUserId,
  Map<String, Birthday>? birthdays,
  DateTime? now,

  /// `false` : visibleBirthdaysProvider reste le vrai, au-dessus du service.
  bool overrideBirthdays = true,
}) {
  return [
    supabaseClientOverride(userId: currentUserId),
    wishlistsRealtimeOverride(wishlists: wishlists),
    friendshipsRealtimeOverride(friendsData: friendsData),
    bookedWishesRealtimeOverride(bookedWishes: bookedWishes),
    if (overrideBirthdays) visibleBirthdaysOverride(birthdays: birthdays),
    if (now != null) clockOverride(now),
  ];
}

/// Override pour visibleBirthdaysProvider (aucun anniversaire par défaut)
Override visibleBirthdaysOverride({Map<String, Birthday>? birthdays}) {
  return visibleBirthdaysProvider.overrideWith(
    (ref) async => (
      userId: ref.watch(currentUserIdProvider),
      birthdays: birthdays ?? const <String, Birthday>{},
    ),
  );
}

/// Override pour clockProvider : date fixe, les tests de compte à rebours ne
/// dépendent pas du jour où ils tournent.
Override clockOverride(DateTime now) {
  return clockProvider.overrideWithValue(() => now);
}

/// Overrides pour tous les écrans avec des données vides
List<Override> emptyDataOverrides({String? currentUserId}) {
  return [
    supabaseClientOverride(userId: currentUserId),
    emptyWishlistsRealtimeOverride(),
    emptyFriendshipsRealtimeOverride(),
    emptyBookedWishesRealtimeOverride(),
  ];
}

/// Overrides pour le SettingsScreen
List<Override> settingsScreenOverrides({
  String? currentUserId,
  String? currentUserEmail,
  Profile? currentUserProfile,
  Birthday? currentUserBirthday,

  /// `false` : currentUserBirthdayProvider reste le vrai, au-dessus du service.
  bool overrideBirthday = true,
  bool signedOut = false,
  List<String> authProviders = const ['email'],
}) {
  return [
    supabaseClientOverride(
      userId: currentUserId,
      userEmail: currentUserEmail,
      signedOut: signedOut,
      authProviders: authProviders,
    ),
    userServiceOverride(userId: currentUserId),
    watchCurrentUserProfileOverride(profile: currentUserProfile),
    if (overrideBirthday)
      currentUserBirthdayOverride(birthday: currentUserBirthday),
    appInfoOverride(),
  ];
}

// =============================================================================
// WISHLIST SCREEN OVERRIDES
// =============================================================================

/// Override pour watchWishlistByIdProvider
///
/// [isDeleted] simule une wishlist supprimée ou archivée (le flux émet `null`)
Override watchWishlistByIdOverride(
  int wishlistId, {
  Wishlist? wishlist,
  bool isDeleted = false,
}) {
  return watchWishlistByIdProvider(wishlistId).overrideWith(
    (ref) => Stream.value(isDeleted ? null : wishlist ?? fakeWishlist1),
  );
}

/// Override pour watchWishsFromWishlistProvider
Override watchWishsFromWishlistOverride(
  int wishlistId, {
  List<Wish>? wishes,
}) {
  return watchWishsFromWishlistProvider(wishlistId).overrideWith(
    (ref) => Stream.value((wishes ?? fakeWishes).toIList()),
  );
}

/// Overrides pour les réceptions : celles du propriétaire de la wishlist
/// (`receipts`) et celles de l'utilisateur courant (`currentUserReceipts`,
/// les mêmes par défaut). Des flux distincts permettent de vérifier qu'un
/// écran lit bien celles du propriétaire.
List<Override> completedWishesOverrides(
  String ownerId, {
  required Stream<IList<CompletedWishWithDetails>> Function() receipts,
  Stream<IList<CompletedWishWithDetails>> Function()? currentUserReceipts,
}) {
  return [
    completedWishesRealtimeProvider.overrideWith(
      (ref) => (currentUserReceipts ?? receipts)(),
    ),
    completedWishesByUserRealtimeProvider(ownerId).overrideWith(
      (ref) => receipts(),
    ),
  ];
}

/// Overrides pour le WishlistScreen
List<Override> wishlistScreenOverrides({
  required int wishlistId,
  Wishlist? wishlist,
  List<Wish>? wishes,
  List<CompletedWishWithDetails>? completedWishes,
  String? currentUserId,
  bool isWishlistDeleted = false,
}) {
  return [
    supabaseClientOverride(userId: currentUserId),
    userServiceOverride(userId: currentUserId),
    watchWishlistByIdOverride(
      wishlistId,
      wishlist: wishlist,
      isDeleted: isWishlistDeleted,
    ),
    watchWishsFromWishlistOverride(wishlistId, wishes: wishes),
    ...completedWishesOverrides(
      wishlist?.idOwner ?? fakeWishlist1.idOwner,
      receipts: () => Stream.value((completedWishes ?? const []).toIList()),
    ),
  ];
}

// =============================================================================
// CURRENT USER BIRTHDAY OVERRIDE
// =============================================================================

/// Override pour currentUserBirthdayProvider (aucun anniversaire par défaut)
Override currentUserBirthdayOverride({Birthday? birthday}) {
  return currentUserBirthdayProvider.overrideWith((ref) async => birthday);
}

// =============================================================================
// CURRENT USER PROFILE OVERRIDE
// =============================================================================

/// Override pour currentUserProfileProvider
Override currentUserProfileOverride({AppUser? appUser}) {
  return currentUserProfileProvider.overrideWith(
    (ref) async => appUser ?? fakeCurrentAppUser,
  );
}

// =============================================================================
// FRIEND DETAILS OVERRIDE
// =============================================================================

/// Override pour friendDetailsRealtimeProvider
Override friendDetailsRealtimeOverride(
  String friendId, {
  FriendDetails? friendDetails,
}) {
  return friendDetailsRealtimeProvider(friendId).overrideWith(
    (ref) => Stream.value(friendDetails ?? fakeFriendDetails),
  );
}

/// Overrides pour FriendDetailsScreen (aucun wish complété par défaut)
List<Override> friendDetailsScreenOverrides({
  required String friendId,
  FriendDetails? friendDetails,
  List<CompletedWishWithDetails>? completedWishes,
  String? currentUserId,
  Map<String, Birthday>? birthdays,
  DateTime? now,

  /// `false` : visibleBirthdaysProvider reste le vrai, au-dessus du service.
  bool overrideBirthdays = true,
}) {
  return [
    supabaseClientOverride(userId: currentUserId),
    friendDetailsRealtimeOverride(friendId, friendDetails: friendDetails),
    completedWishesByUserRealtimeProvider(friendId).overrideWith(
      (ref) => Stream.value((completedWishes ?? const []).toIList()),
    ),
    if (overrideBirthdays) visibleBirthdaysOverride(birthdays: birthdays),
    if (now != null) clockOverride(now),
  ];
}

// =============================================================================
// WISH SCREEN OVERRIDES
// =============================================================================

/// Override pour watchWishByIdProvider
Override watchWishByIdOverride(int wishId, {Wish? wish}) {
  return watchWishByIdProvider(wishId).overrideWith(
    (ref) => Stream.value(wish ?? fakeWish1),
  );
}

/// Overrides pour ConsultWishScreen et EditWishScreen
///
/// `receipts` : réceptions du propriétaire de la wishlist ;
/// `currentUserReceipts` : celles de l'utilisateur courant. Aucune par défaut.
List<Override> wishScreenOverrides({
  required int wishId,
  required int wishlistId,
  Wish? wish,
  Wishlist? wishlist,
  String? currentUserId,
  Stream<IList<CompletedWishWithDetails>> Function()? receipts,
  Stream<IList<CompletedWishWithDetails>> Function()? currentUserReceipts,
}) {
  Stream<IList<CompletedWishWithDetails>> noReceipts() =>
      Stream.value(const IListConst([]));

  return [
    supabaseClientOverride(userId: currentUserId),
    userServiceOverride(userId: currentUserId),
    watchWishByIdOverride(wishId, wish: wish),
    watchWishlistByIdOverride(wishlistId, wishlist: wishlist),
    ...completedWishesOverrides(
      wishlist?.idOwner ?? fakeWishlist1.idOwner,
      receipts: receipts ?? noReceipts,
      currentUserReceipts: currentUserReceipts ?? noReceipts,
    ),
  ];
}

// =============================================================================
// CHANGE PSEUDO SCREEN OVERRIDES
// =============================================================================

/// Overrides pour ChangePseudoScreen
List<Override> changePseudoScreenOverrides({
  AppUser? currentUser,
  String? currentUserId,
}) {
  return [
    supabaseClientOverride(userId: currentUserId),
    userServiceOverride(userId: currentUserId),
    currentUserProfileOverride(appUser: currentUser),
  ];
}

// =============================================================================
// PSEUDO SCREEN OVERRIDES
// =============================================================================

/// Overrides pour PseudoScreen
List<Override> pseudoScreenOverrides({String? currentUserId}) {
  return [
    supabaseClientOverride(userId: currentUserId),
    userServiceOverride(userId: currentUserId),
  ];
}
