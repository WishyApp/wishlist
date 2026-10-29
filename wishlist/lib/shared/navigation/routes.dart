import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wishlist/modules/auth/view/auth_screen.dart';
import 'package:wishlist/modules/auth/view/birthday_step_screen.dart';
import 'package:wishlist/modules/auth/view/forgot_password_screen.dart';
import 'package:wishlist/modules/auth/view/pseudo_screen.dart';
import 'package:wishlist/modules/auth/view/reset_password_screen.dart';
import 'package:wishlist/modules/completed_wishes/view/completed_wishes_screen.dart';
import 'package:wishlist/modules/friends/view/screens/friend_details_screen.dart';
import 'package:wishlist/modules/profile/view/edit_profile_screen.dart';
import 'package:wishlist/modules/settings/change_birthday/view/change_birthday_screen.dart';
import 'package:wishlist/modules/settings/change_password/view/change_password_screen.dart';
import 'package:wishlist/modules/settings/change_pseudo/view/change_pseudo_screen.dart';
import 'package:wishlist/modules/settings/view/settings_screen.dart';
import 'package:wishlist/modules/wishlists/view/default_received_day.dart';
import 'package:wishlist/modules/wishlists/view/wishlist_screen.dart';
import 'package:wishlist/modules/wishlists/view/wishlist_settings_screen.dart';
import 'package:wishlist/modules/wishs/view/screens/add_wish_screen.dart';
import 'package:wishlist/modules/wishs/view/screens/consult_wish_screen.dart';
import 'package:wishlist/modules/wishs/view/screens/edit_wish_screen.dart';
import 'package:wishlist/modules/wishs/view/wish_form_screen.dart';
import 'package:wishlist/shared/models/wish_prefill_data/wish_prefill_data.dart';
import 'package:wishlist/shared/navigation/authenticated_route.dart';
import 'package:wishlist/shared/navigation/floating_nav_bar_navigator.dart';
import 'package:wishlist/shared/navigation/redirect_target.dart';

part 'routes.g.dart';

// Route principale avec navigation bar
@TypedGoRoute<HomeRoute>(
  path: '/',
  routes: [
    // Pseudo (enfant de home)
    TypedGoRoute<PseudoRoute>(
      path: 'pseudo',
    ),
    // Optional birthday step, after the pseudo at signup
    TypedGoRoute<BirthdayStepRoute>(
      path: 'birthday',
    ),
    // Edit profile (photo, pseudo, birthday)
    TypedGoRoute<EditProfileRoute>(
      path: 'profile',
      routes: [
        TypedGoRoute<ChangePseudoRoute>(
          path: 'change-pseudo',
        ),
        TypedGoRoute<ChangeBirthdayRoute>(
          path: 'change-birthday',
        ),
      ],
    ),
    // Settings et ses sous-routes
    TypedGoRoute<SettingsRoute>(
      path: 'settings',
      routes: [
        TypedGoRoute<ChangePasswordRoute>(
          path: 'change-password',
        ),
      ],
    ),
    // Wishes received by the current user
    TypedGoRoute<CompletedWishesRoute>(
      path: 'completed-wishes',
    ),
    // Wishlist et ses sous-routes
    TypedGoRoute<WishlistRoute>(
      path: 'wishlist/:wishlistId',
      routes: [
        TypedGoRoute<CreateWishRoute>(
          path: 'create-wish',
        ),
        TypedGoRoute<WishlistSettingsRoute>(
          path: 'settings',
        ),
        TypedGoRoute<ConsultWishRoute>(
          path: 'wish/:wishId',
          routes: [
            TypedGoRoute<EditWishRoute>(
              path: 'edit',
            ),
          ],
        ),
      ],
    ),
    // Friend details (enfant de home)
    TypedGoRoute<FriendDetailsRoute>(
      path: 'friend/:friendId',
      routes: [
        TypedGoRoute<FriendCompletedWishesRoute>(
          path: 'completed-wishes',
        ),
      ],
    ),
    // Ajouter un wish (partage externe, sans wishlist connue)
    TypedGoRoute<AddWishRoute>(
      path: 'add-wish',
    ),
  ],
)
class HomeRoute extends AuthenticatedRoute {
  @override
  Widget buildScreen(BuildContext context, GoRouterState state) {
    final tab = homeTabFromQuery(state.uri.queryParameters['tab']);
    return FloatingNavBarNavigator(
      key: ValueKey(tab),
      currentTab: tab,
    );
  }
}

/// Parses the optional `?tab=<index>` of the home route (opens a tab
/// directly). Falls back to the home tab when missing or invalid.
FloatingNavBarTab homeTabFromQuery(String? value) {
  final index = int.tryParse(value ?? '');
  if (index == null || index < 0 || index >= FloatingNavBarTab.values.length) {
    return FloatingNavBarTab.home;
  }
  return FloatingNavBarTab.values[index];
}

class PseudoRoute extends AuthenticatedRoute {
  @override
  Widget buildScreen(BuildContext context, GoRouterState state) => PseudoScreen(
        redirectTo: sanitizeRedirectTarget(
          state.uri.queryParameters['redirectTo'],
        ),
      );
}

/// Optional step of the signup, right after the pseudo. It opens the deep link
/// the user came from (the `redirectTo` query parameter) once it is done.
class BirthdayStepRoute extends AuthenticatedRoute {
  @override
  Widget buildScreen(BuildContext context, GoRouterState state) =>
      BirthdayStepScreen(
        redirectTo: sanitizeRedirectTarget(
          state.uri.queryParameters['redirectTo'],
        ),
      );
}

class WishlistRoute extends AuthenticatedRoute {
  WishlistRoute({
    required this.wishlistId,
    this.receivedOn,
  });

  final int wishlistId;

  /// The party day (`yyyy-MM-dd`) of the after-party card that opened the
  /// list: the day proposed by default when marking a wish received.
  final String? receivedOn;

  @override
  Widget buildScreen(BuildContext context, GoRouterState state) {
    return WishlistScreen(
      wishlistId: wishlistId,
      receivedOn: parseReceivedOn(receivedOn),
    );
  }
}

class WishlistSettingsRoute extends AuthenticatedRoute {
  WishlistSettingsRoute({
    required this.wishlistId,
  });

  final int wishlistId;

  @override
  Widget buildScreen(BuildContext context, GoRouterState state) {
    return WishlistSettingsScreen(
      wishlistId: wishlistId,
    );
  }
}

class CreateWishRoute extends AuthenticatedRoute {
  CreateWishRoute({
    required this.wishlistId,
    this.name,
    this.link,
    this.description,
    this.price,
    this.$extra,
  });

  final int wishlistId;
  final String? name;
  final String? link;
  final String? description;
  final String? price;

  /// Chemin local de l'image partagée. Passé en `extra` et pas en query
  /// param : un lien profond ne doit pas pouvoir désigner un fichier de l'app.
  final String? $extra;

  WishPrefillData? get prefill => WishPrefillData.fromRouteParams(
        name: name,
        link: link,
        description: description,
        price: price,
      );

  @override
  Widget buildScreen(BuildContext context, GoRouterState state) {
    return WishFormScreen(
      wishlistId: wishlistId,
      prefill: prefill,
      sharedImagePath: $extra,
    );
  }
}

class ConsultWishRoute extends AuthenticatedRoute {
  ConsultWishRoute(
    this.wishlistId,
    this.wishId, {
    required this.wishIds,
    this.showActions = true,
    this.quantityDisplay = WishQuantityDisplay.total,
    this.completedByUserId,
    this.receivedOn,
  });
  final int wishlistId;
  final int wishId;
  final List<int> wishIds;
  final bool showActions;
  final WishQuantityDisplay quantityDisplay;

  /// See [ConsultWishScreen.completedByUserId]
  final String? completedByUserId;

  /// The party day (`yyyy-MM-dd`) of the wishlist the wish was opened from, see
  /// [WishlistRoute.receivedOn]
  final String? receivedOn;

  /// Liste ordonnée des wishs à afficher. Retombe sur `[wishId]` si le
  /// paramètre `wish-ids` est absent (deep link) ou ne contient pas `wishId`.
  List<int> get effectiveWishIds =>
      wishIds.contains(wishId) ? wishIds : [wishId];

  @override
  Widget buildScreen(BuildContext context, GoRouterState state) {
    final ids = effectiveWishIds;

    return ConsultWishScreen(
      wishIds: ids,
      initialIndex: ids.indexOf(wishId),
      showActions: showActions,
      quantityDisplay: quantityDisplay,
      completedByUserId: completedByUserId,
      receivedOn: parseReceivedOn(receivedOn),
    );
  }
}

class EditWishRoute extends AuthenticatedRoute {
  EditWishRoute({
    required this.wishlistId,
    required this.wishId,
  });

  final int wishlistId;
  final int wishId;

  @override
  Widget buildScreen(BuildContext context, GoRouterState state) {
    return EditWishScreen(wishId: wishId);
  }
}

class SettingsRoute extends AuthenticatedRoute {
  @override
  Widget buildScreen(BuildContext context, GoRouterState state) =>
      const SettingsScreen();
}

class ChangePasswordRoute extends AuthenticatedRoute {
  @override
  Widget buildScreen(BuildContext context, GoRouterState state) =>
      const ChangePasswordScreen();
}

class EditProfileRoute extends AuthenticatedRoute {
  @override
  Widget buildScreen(BuildContext context, GoRouterState state) =>
      const EditProfileScreen();
}

class ChangePseudoRoute extends AuthenticatedRoute {
  @override
  Widget buildScreen(BuildContext context, GoRouterState state) =>
      const ChangePseudoScreen();
}

class ChangeBirthdayRoute extends AuthenticatedRoute {
  @override
  Widget buildScreen(BuildContext context, GoRouterState state) =>
      const ChangeBirthdayScreen();
}

class CompletedWishesRoute extends AuthenticatedRoute {
  @override
  Widget buildScreen(BuildContext context, GoRouterState state) =>
      const CompletedWishesScreen();
}

class FriendDetailsRoute extends AuthenticatedRoute {
  FriendDetailsRoute(this.friendId);
  final String friendId;

  @override
  Widget buildScreen(BuildContext context, GoRouterState state) {
    return FriendDetailsScreen(friendId: friendId);
  }
}

class FriendCompletedWishesRoute extends AuthenticatedRoute {
  FriendCompletedWishesRoute(this.friendId);
  final String friendId;

  @override
  Widget buildScreen(BuildContext context, GoRouterState state) {
    return CompletedWishesScreen(userId: friendId);
  }
}

class AddWishRoute extends AuthenticatedRoute {
  AddWishRoute({
    this.name,
    this.link,
    this.description,
    this.price,
  });

  final String? name;
  final String? link;
  final String? description;
  final String? price;

  WishPrefillData? get prefill => WishPrefillData.fromRouteParams(
        name: name,
        link: link,
        description: description,
        price: price,
      );

  @override
  Widget buildScreen(BuildContext context, GoRouterState state) {
    return AddWishScreen(prefill: prefill);
  }
}

// Route auth séparée (hors de la navigation principale)
@TypedGoRoute<AuthRoute>(
  path: '/auth',
  routes: [
    TypedGoRoute<ForgotPasswordRoute>(
      path: 'forgot-password',
    ),
    TypedGoRoute<ResetPasswordRoute>(
      path: 'reset-password',
    ),
  ],
)
class AuthRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) => AuthScreen(
        redirectTo: state.uri.queryParameters['redirectTo'],
      );
}

class ForgotPasswordRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ForgotPasswordScreen();
}

class ResetPasswordRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ResetPasswordScreen();
}
