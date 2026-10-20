import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wishlist/modules/auth/view/auth_screen.dart';
import 'package:wishlist/modules/auth/view/forgot_password_screen.dart';
import 'package:wishlist/modules/auth/view/pseudo_screen.dart';
import 'package:wishlist/modules/auth/view/reset_password_screen.dart';
import 'package:wishlist/modules/completed_wishes/view/completed_wishes_screen.dart';
import 'package:wishlist/modules/friends/view/screens/friend_details_screen.dart';
import 'package:wishlist/modules/settings/change_password/view/change_password_screen.dart';
import 'package:wishlist/modules/settings/change_pseudo/view/change_pseudo_screen.dart';
import 'package:wishlist/modules/settings/view/settings_screen.dart';
import 'package:wishlist/modules/wishlists/view/wishlist_screen.dart';
import 'package:wishlist/modules/wishs/view/screens/add_wish_screen.dart';
import 'package:wishlist/modules/wishs/view/screens/consult_wish_screen.dart';
import 'package:wishlist/modules/wishs/view/screens/edit_wish_screen.dart';
import 'package:wishlist/modules/wishs/view/wish_form_screen.dart';
import 'package:wishlist/shared/models/wish_prefill_data/wish_prefill_data.dart';
import 'package:wishlist/shared/navigation/floating_nav_bar_navigator.dart';

part 'routes.g.dart';

// Route principale avec navigation bar
@TypedGoRoute<HomeRoute>(
  path: '/',
  routes: [
    // Pseudo (enfant de home)
    TypedGoRoute<PseudoRoute>(
      path: 'pseudo',
    ),
    // Settings et ses sous-routes
    TypedGoRoute<SettingsRoute>(
      path: 'settings',
      routes: [
        TypedGoRoute<ChangePasswordRoute>(
          path: 'change-password',
        ),
        TypedGoRoute<ChangePseudoRoute>(
          path: 'change-pseudo',
        ),
        TypedGoRoute<CompletedWishesRoute>(
          path: 'completed-wishes',
        ),
      ],
    ),
    // Wishlist et ses sous-routes
    TypedGoRoute<WishlistRoute>(
      path: 'wishlist/:wishlistId',
      routes: [
        TypedGoRoute<CreateWishRoute>(
          path: 'create-wish',
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
    ),
    // Ajouter un wish (partage externe, sans wishlist connue)
    TypedGoRoute<AddWishRoute>(
      path: 'add-wish',
    ),
  ],
)
class HomeRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) {
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

class PseudoRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) => PseudoScreen(
        redirectTo: state.uri.queryParameters['redirectTo'],
      );
}

class WishlistRoute extends GoRouteData {
  WishlistRoute({
    required this.wishlistId,
  });

  final int wishlistId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return WishlistScreen(
      wishlistId: wishlistId,
    );
  }
}

class CreateWishRoute extends GoRouteData {
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
  Widget build(BuildContext context, GoRouterState state) {
    return WishFormScreen(
      wishlistId: wishlistId,
      prefill: prefill,
      sharedImagePath: $extra,
    );
  }
}

class ConsultWishRoute extends GoRouteData {
  ConsultWishRoute(
    this.wishlistId,
    this.wishId, {
    required this.wishIds,
    this.showActions = true,
    this.quantityDisplay = WishQuantityDisplay.total,
  });
  final int wishlistId;
  final int wishId;
  final List<int> wishIds;
  final bool showActions;
  final WishQuantityDisplay quantityDisplay;

  /// Liste ordonnée des wishs à afficher. Retombe sur `[wishId]` si le
  /// paramètre `wish-ids` est absent (deep link) ou ne contient pas `wishId`.
  List<int> get effectiveWishIds =>
      wishIds.contains(wishId) ? wishIds : [wishId];

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final ids = effectiveWishIds;

    return ConsultWishScreen(
      wishIds: ids,
      initialIndex: ids.indexOf(wishId),
      showActions: showActions,
      quantityDisplay: quantityDisplay,
    );
  }
}

class EditWishRoute extends GoRouteData {
  EditWishRoute({
    required this.wishlistId,
    required this.wishId,
  });

  final int wishlistId;
  final int wishId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return EditWishScreen(wishId: wishId);
  }
}

class SettingsRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SettingsScreen();
}

class ChangePasswordRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ChangePasswordScreen();
}

class ChangePseudoRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ChangePseudoScreen();
}

class CompletedWishesRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const CompletedWishesScreen();
}

class FriendDetailsRoute extends GoRouteData {
  FriendDetailsRoute(this.friendId);
  final String friendId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return FriendDetailsScreen(friendId: friendId);
  }
}

class AddWishRoute extends GoRouteData {
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
  Widget build(BuildContext context, GoRouterState state) {
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
