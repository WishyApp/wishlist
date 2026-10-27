import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/app/config/config.dart';
import 'package:wishlist/app/config/deeplink_config.dart';
import 'package:wishlist/main.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/non_null_extensions/go_true_client_non_null_getter_user_extension.dart';
import 'package:wishlist/shared/infra/social_sign_in_client.dart';
import 'package:wishlist/shared/infra/utils/auth_user_message_key.dart';
import 'package:wishlist/shared/navigation/routes.dart';

class AuthService {
  AuthService({GoTrueClient? auth, SocialSignInClient? socialSignIn})
      : _authOverride = auth,
        _socialSignIn = socialSignIn ?? SocialSignInClient();

  final GoTrueClient? _authOverride;
  final SocialSignInClient _socialSignIn;

  GoTrueClient get _auth => _authOverride ?? supabase.auth;

  static final AuthService _instance = AuthService();

  static AuthService get instance => _instance;

  Future<void> signOut(BuildContext context, WidgetRef ref) async {
    await _auth.signOut();
    await _signOutOfGoogle();
  }

  Future<void> _signOutOfGoogle() async {
    try {
      await _socialSignIn.signOutOfGoogle();
    } catch (e) {
      // The Supabase session is gone, which is what signing out means: a
      // Google account still remembered only skips the picker next time.
      debugPrint('Could not sign out of Google: $e');
    }
  }

  /// Returns false when the user dismissed the Google sheet.
  ///
  /// A first sign-in creates the account: the router then asks for the
  /// pseudo, as after an email sign-up.
  Future<bool> signInWithGoogle(GoogleSignInConfig config) async {
    final token = await _socialSignIn.googleIdToken(config);
    if (token == null) {
      return false;
    }

    await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: token.idToken,
      nonce: token.rawNonce,
    );
    return true;
  }

  /// Returns false when the user dismissed the Apple sheet.
  Future<bool> signInWithApple() async {
    final token = await _socialSignIn.appleIdToken();
    if (token == null) {
      return false;
    }

    await _auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: token.idToken,
      nonce: token.rawNonce,
    );
    return true;
  }

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    final isEmail = EmailValidator.validate(identifier);
    final email =
        isEmail ? identifier : await _resolveEmailFromPseudo(identifier);

    await _auth.signInWithPassword(email: email, password: password);
  }

  Future<String> _resolveEmailFromPseudo(String pseudo) async {
    String? email;
    try {
      email = await supabase.rpc<String?>(
        'get_email_by_pseudo',
        params: {'p_pseudo': pseudo},
      );
    } on PostgrestException catch (e) {
      // PGRST202: the function does not exist yet on a database that has not
      // received its migration.
      if (e.code != 'PGRST202') {
        rethrow;
      }
      email = await _resolveEmailFromPseudoThroughView(pseudo);
    }

    if (email == null) {
      throw const AuthException('User not found', statusCode: '404');
    }

    return email;
  }

  Future<String?> _resolveEmailFromPseudoThroughView(String pseudo) async {
    final response = await supabase
        .from('users_profiles')
        .select('user->>email')
        .eq('profile->>pseudo', pseudo)
        .maybeSingle();

    return response?['email'] as String?;
  }

  Future<void> signUp({required String email, required String password}) async {
    await _auth.signUp(email: email, password: password);
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final bool oldPasswordIsCorrect;
    try {
      oldPasswordIsCorrect = await confirmPasswordIsCorrect(oldPassword);
    } on AuthException catch (e) {
      // Network failures (AuthRetryableFetchException, no status code) and
      // server errors: not a wrong password. Keep the original as the cause.
      final statusCode = e.statusCode;
      throw AppException(
        statusCode: statusCode != null ? int.parse(statusCode) : 500,
        message: e.message,
        cause: e,
      );
    } on AppException {
      // Not signed in (currentUserNonNull): already an AppException.
      rethrow;
    } catch (e) {
      // Anything else unexpected: still not a wrong password.
      throw AppException(
        statusCode: 500,
        message: 'Could not verify the old password',
        cause: e,
      );
    }
    if (!oldPasswordIsCorrect) {
      throw AppException(
        statusCode: 403,
        message: 'Old password is incorrect',
        userMessageKey: AppUserMessageKey.oldPasswordIncorrect,
      );
    }
    try {
      await _auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      final statusCode = e.statusCode;
      final statusCodeInt = statusCode != null ? int.parse(statusCode) : 500;

      throw AppException(
        statusCode: statusCodeInt,
        message: e.message,
        userMessageKey: userMessageKeyForAuthException(e),
        cause: e,
      );
    }
  }

  /// Returns false only when the credentials are rejected; any other failure
  /// (network, server) propagates so callers don't report it as a wrong
  /// password.
  ///
  /// Re-signs in with the current user's email: gotrue offers no password-only
  /// check (`reauthenticate` sends an email nonce instead), so this refreshes
  /// the session of the same user and emits an auth state change.
  Future<bool> confirmPasswordIsCorrect(String password) async {
    final user = _auth.currentUserNonNull;
    try {
      await _auth.signInWithPassword(
        email: user.email,
        password: password,
      );
      return true;
    } on AuthException catch (e) {
      if (isInvalidCredentialsException(e)) {
        return false;
      }
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      final resetPasswordRouteLocation = ResetPasswordRoute().location;

      final redirectUrl = DeeplinkConfig.buildDeeplinkUri(
        path: resetPasswordRouteLocation,
      ).toString();

      await _auth.resetPasswordForEmail(email, redirectTo: redirectUrl);
    } on AuthException catch (e) {
      final statusCode = e.statusCode;
      throw AppException(
        statusCode: statusCode != null ? int.parse(statusCode) : 500,
        message: e.message,
        cause: e,
      );
    }
  }

  Future<void> resetPassword({required String newPassword}) async {
    try {
      await _auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      final statusCode = e.statusCode;
      final statusCodeInt = statusCode != null ? int.parse(statusCode) : 500;

      throw AppException(
        statusCode: statusCodeInt,
        message: e.message,
        userMessageKey: userMessageKeyForAuthException(e),
        cause: e,
      );
    }
  }

  Future<void> deleteAccount() async {
    try {
      // Appeler une Edge Function qui gère toute la suppression côté serveur
      // (fichiers du storage + suppression de l'utilisateur)
      await supabase.functions.invoke('delete-user-account');

      // Déconnecter l'utilisateur après la suppression
      await _auth.signOut();
      await _signOutOfGoogle();
    } catch (e) {
      if (e is AuthException) {
        final statusCode = e.statusCode;
        throw AppException(
          statusCode: statusCode != null ? int.parse(statusCode) : 500,
          message: e.message,
          cause: e,
        );
      }
      throw AppException(
        statusCode: 500,
        message: 'Failed to delete account',
        cause: e,
      );
    }
  }
}

final authServiceProvider = Provider((ref) => AuthService.instance);

/// Null when the environment has no Google client IDs: the Google button is
/// then hidden. Overridden in `main.dart` with the loaded config.
final googleSignInConfigProvider = Provider<GoogleSignInConfig?>((ref) => null);
