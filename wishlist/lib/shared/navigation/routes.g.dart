// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
      $homeRoute,
      $authRoute,
    ];

RouteBase get $homeRoute => GoRouteData.$route(
      path: '/',
      factory: $HomeRouteExtension._fromState,
      routes: [
        GoRouteData.$route(
          path: 'pseudo',
          factory: $PseudoRouteExtension._fromState,
        ),
        GoRouteData.$route(
          path: 'birthday',
          factory: $BirthdayStepRouteExtension._fromState,
        ),
        GoRouteData.$route(
          path: 'settings',
          factory: $SettingsRouteExtension._fromState,
          routes: [
            GoRouteData.$route(
              path: 'change-password',
              factory: $ChangePasswordRouteExtension._fromState,
            ),
            GoRouteData.$route(
              path: 'change-pseudo',
              factory: $ChangePseudoRouteExtension._fromState,
            ),
            GoRouteData.$route(
              path: 'change-birthday',
              factory: $ChangeBirthdayRouteExtension._fromState,
            ),
            GoRouteData.$route(
              path: 'completed-wishes',
              factory: $CompletedWishesRouteExtension._fromState,
            ),
          ],
        ),
        GoRouteData.$route(
          path: 'wishlist/:wishlistId',
          factory: $WishlistRouteExtension._fromState,
          routes: [
            GoRouteData.$route(
              path: 'create-wish',
              factory: $CreateWishRouteExtension._fromState,
            ),
            GoRouteData.$route(
              path: 'settings',
              factory: $WishlistSettingsRouteExtension._fromState,
            ),
            GoRouteData.$route(
              path: 'wish/:wishId',
              factory: $ConsultWishRouteExtension._fromState,
              routes: [
                GoRouteData.$route(
                  path: 'edit',
                  factory: $EditWishRouteExtension._fromState,
                ),
              ],
            ),
          ],
        ),
        GoRouteData.$route(
          path: 'friend/:friendId',
          factory: $FriendDetailsRouteExtension._fromState,
          routes: [
            GoRouteData.$route(
              path: 'completed-wishes',
              factory: $FriendCompletedWishesRouteExtension._fromState,
            ),
          ],
        ),
        GoRouteData.$route(
          path: 'add-wish',
          factory: $AddWishRouteExtension._fromState,
        ),
      ],
    );

extension $HomeRouteExtension on HomeRoute {
  static HomeRoute _fromState(GoRouterState state) => HomeRoute();

  String get location => GoRouteData.$location(
        '/',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $PseudoRouteExtension on PseudoRoute {
  static PseudoRoute _fromState(GoRouterState state) => PseudoRoute();

  String get location => GoRouteData.$location(
        '/pseudo',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $BirthdayStepRouteExtension on BirthdayStepRoute {
  static BirthdayStepRoute _fromState(GoRouterState state) =>
      BirthdayStepRoute();

  String get location => GoRouteData.$location(
        '/birthday',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $SettingsRouteExtension on SettingsRoute {
  static SettingsRoute _fromState(GoRouterState state) => SettingsRoute();

  String get location => GoRouteData.$location(
        '/settings',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $ChangePasswordRouteExtension on ChangePasswordRoute {
  static ChangePasswordRoute _fromState(GoRouterState state) =>
      ChangePasswordRoute();

  String get location => GoRouteData.$location(
        '/settings/change-password',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $ChangePseudoRouteExtension on ChangePseudoRoute {
  static ChangePseudoRoute _fromState(GoRouterState state) =>
      ChangePseudoRoute();

  String get location => GoRouteData.$location(
        '/settings/change-pseudo',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $ChangeBirthdayRouteExtension on ChangeBirthdayRoute {
  static ChangeBirthdayRoute _fromState(GoRouterState state) =>
      ChangeBirthdayRoute();

  String get location => GoRouteData.$location(
        '/settings/change-birthday',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $CompletedWishesRouteExtension on CompletedWishesRoute {
  static CompletedWishesRoute _fromState(GoRouterState state) =>
      CompletedWishesRoute();

  String get location => GoRouteData.$location(
        '/settings/completed-wishes',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $WishlistRouteExtension on WishlistRoute {
  static WishlistRoute _fromState(GoRouterState state) => WishlistRoute(
        wishlistId: int.parse(state.pathParameters['wishlistId']!),
      );

  String get location => GoRouteData.$location(
        '/wishlist/${Uri.encodeComponent(wishlistId.toString())}',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $CreateWishRouteExtension on CreateWishRoute {
  static CreateWishRoute _fromState(GoRouterState state) => CreateWishRoute(
        wishlistId: int.parse(state.pathParameters['wishlistId']!),
        name: state.uri.queryParameters['name'],
        link: state.uri.queryParameters['link'],
        description: state.uri.queryParameters['description'],
        price: state.uri.queryParameters['price'],
        $extra: state.extra as String?,
      );

  String get location => GoRouteData.$location(
        '/wishlist/${Uri.encodeComponent(wishlistId.toString())}/create-wish',
        queryParams: {
          if (name != null) 'name': name,
          if (link != null) 'link': link,
          if (description != null) 'description': description,
          if (price != null) 'price': price,
        },
      );

  void go(BuildContext context) => context.go(location, extra: $extra);

  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: $extra);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: $extra);

  void replace(BuildContext context) =>
      context.replace(location, extra: $extra);
}

extension $WishlistSettingsRouteExtension on WishlistSettingsRoute {
  static WishlistSettingsRoute _fromState(GoRouterState state) =>
      WishlistSettingsRoute(
        wishlistId: int.parse(state.pathParameters['wishlistId']!),
      );

  String get location => GoRouteData.$location(
        '/wishlist/${Uri.encodeComponent(wishlistId.toString())}/settings',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $ConsultWishRouteExtension on ConsultWishRoute {
  static ConsultWishRoute _fromState(GoRouterState state) => ConsultWishRoute(
        int.parse(state.pathParameters['wishlistId']!),
        int.parse(state.pathParameters['wishId']!),
        wishIds:
            state.uri.queryParametersAll['wish-ids']?.map(int.parse).toList() ??
                const [],
        showActions: _$convertMapValue(
                'show-actions', state.uri.queryParameters, _$boolConverter) ??
            true,
        quantityDisplay: _$convertMapValue(
                'quantity-display',
                state.uri.queryParameters,
                _$WishQuantityDisplayEnumMap._$fromName) ??
            WishQuantityDisplay.total,
        completedByUserId: state.uri.queryParameters['completed-by-user-id'],
      );

  String get location => GoRouteData.$location(
        '/wishlist/${Uri.encodeComponent(wishlistId.toString())}/wish/${Uri.encodeComponent(wishId.toString())}',
        queryParams: {
          'wish-ids': wishIds.map((e) => e.toString()).toList(),
          if (showActions != true) 'show-actions': showActions.toString(),
          if (quantityDisplay != WishQuantityDisplay.total)
            'quantity-display': _$WishQuantityDisplayEnumMap[quantityDisplay],
          if (completedByUserId != null)
            'completed-by-user-id': completedByUserId,
        },
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

const _$WishQuantityDisplayEnumMap = {
  WishQuantityDisplay.total: 'total',
  WishQuantityDisplay.pending: 'pending',
  WishQuantityDisplay.booked: 'booked',
  WishQuantityDisplay.myBooked: 'my-booked',
  WishQuantityDisplay.completed: 'completed',
};

extension $EditWishRouteExtension on EditWishRoute {
  static EditWishRoute _fromState(GoRouterState state) => EditWishRoute(
        wishlistId: int.parse(state.pathParameters['wishlistId']!),
        wishId: int.parse(state.pathParameters['wishId']!),
      );

  String get location => GoRouteData.$location(
        '/wishlist/${Uri.encodeComponent(wishlistId.toString())}/wish/${Uri.encodeComponent(wishId.toString())}/edit',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $FriendDetailsRouteExtension on FriendDetailsRoute {
  static FriendDetailsRoute _fromState(GoRouterState state) =>
      FriendDetailsRoute(
        state.pathParameters['friendId']!,
      );

  String get location => GoRouteData.$location(
        '/friend/${Uri.encodeComponent(friendId)}',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $FriendCompletedWishesRouteExtension on FriendCompletedWishesRoute {
  static FriendCompletedWishesRoute _fromState(GoRouterState state) =>
      FriendCompletedWishesRoute(
        state.pathParameters['friendId']!,
      );

  String get location => GoRouteData.$location(
        '/friend/${Uri.encodeComponent(friendId)}/completed-wishes',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $AddWishRouteExtension on AddWishRoute {
  static AddWishRoute _fromState(GoRouterState state) => AddWishRoute(
        name: state.uri.queryParameters['name'],
        link: state.uri.queryParameters['link'],
        description: state.uri.queryParameters['description'],
        price: state.uri.queryParameters['price'],
      );

  String get location => GoRouteData.$location(
        '/add-wish',
        queryParams: {
          if (name != null) 'name': name,
          if (link != null) 'link': link,
          if (description != null) 'description': description,
          if (price != null) 'price': price,
        },
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

T? _$convertMapValue<T>(
  String key,
  Map<String, String> map,
  T Function(String) converter,
) {
  final value = map[key];
  return value == null ? null : converter(value);
}

bool _$boolConverter(String value) {
  switch (value) {
    case 'true':
      return true;
    case 'false':
      return false;
    default:
      throw UnsupportedError('Cannot convert "$value" into a bool.');
  }
}

extension<T extends Enum> on Map<T, String> {
  T _$fromName(String value) =>
      entries.singleWhere((element) => element.value == value).key;
}

RouteBase get $authRoute => GoRouteData.$route(
      path: '/auth',
      factory: $AuthRouteExtension._fromState,
      routes: [
        GoRouteData.$route(
          path: 'forgot-password',
          factory: $ForgotPasswordRouteExtension._fromState,
        ),
        GoRouteData.$route(
          path: 'reset-password',
          factory: $ResetPasswordRouteExtension._fromState,
        ),
      ],
    );

extension $AuthRouteExtension on AuthRoute {
  static AuthRoute _fromState(GoRouterState state) => AuthRoute();

  String get location => GoRouteData.$location(
        '/auth',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $ForgotPasswordRouteExtension on ForgotPasswordRoute {
  static ForgotPasswordRoute _fromState(GoRouterState state) =>
      ForgotPasswordRoute();

  String get location => GoRouteData.$location(
        '/auth/forgot-password',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $ResetPasswordRouteExtension on ResetPasswordRoute {
  static ResetPasswordRoute _fromState(GoRouterState state) =>
      ResetPasswordRoute();

  String get location => GoRouteData.$location(
        '/auth/reset-password',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}
