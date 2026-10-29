import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/app/config/config.dart';
import 'package:wishlist/shared/infra/utils/network_error.dart';
import 'package:wishlist/shared/infra/utils/social_sign_in_error.dart';

/// An ID token from a native sign-in, with the raw nonce whose SHA-256 the
/// provider embedded in it: Supabase hashes [rawNonce] to check the token.
class SocialIdToken {
  const SocialIdToken({required this.idToken, required this.rawNonce});

  final String idToken;
  final String rawNonce;
}

/// Runs the native Google and Apple sign-in sheets.
///
/// Each method returns null when the user dismisses the sheet.
class SocialSignInClient {
  SocialSignInClient({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;

  /// Apple sign-in is offered on iOS only, where the App Store requires it
  /// next to Google.
  static bool get isAppleAvailable =>
      defaultTargetPlatform == TargetPlatform.iOS;

  /// The raw nonce of each initialized [GoogleSignIn], keyed by the instance:
  /// it must be initialized once per process, whichever client asks first.
  ///
  /// google_sign_in takes its nonce once, at initialization: every Google
  /// token of a run carries the same one, which ties a token to this run of
  /// the app, not to one attempt.
  static final _googleRawNonces = Expando<Future<String>>();

  /// Initializes Google once, and again after a failed initialization.
  Future<String> _initializedGoogle(GoogleSignInConfig config) async {
    final initialization =
        _googleRawNonces[_googleSignIn] ??= _initializeGoogle(config);
    try {
      return await initialization;
    } catch (_) {
      if (identical(_googleRawNonces[_googleSignIn], initialization)) {
        _googleRawNonces[_googleSignIn] = null;
      }
      rethrow;
    }
  }

  Future<SocialIdToken?> googleIdToken(GoogleSignInConfig config) async {
    final rawNonce = await _initializedGoogle(config);

    final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google returned no ID token');
    }

    return SocialIdToken(idToken: idToken, rawNonce: rawNonce);
  }

  Future<String> _initializeGoogle(GoogleSignInConfig config) async {
    final rawNonce = _generateRawNonce();
    await _googleSignIn.initialize(
      // On iOS, the client ID comes from GIDClientID in Info.plist.
      serverClientId: config.webClientId,
      nonce: _sha256(rawNonce),
    );
    return rawNonce;
  }

  Future<SocialIdToken?> appleIdToken() async {
    final rawNonce = _generateRawNonce();

    final credential = await _appleCredential(
      scopes: [AppleIDAuthorizationScopes.email],
      nonce: _sha256(rawNonce),
    );
    if (credential == null) {
      return null;
    }

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple returned no ID token');
    }

    return SocialIdToken(idToken: idToken, rawNonce: rawNonce);
  }

  /// A fresh authorization code from the Apple sheet, for the server to
  /// revoke the account's Apple tokens when it is deleted.
  Future<String?> appleAuthorizationCode() async {
    final credential = await _appleCredential(scopes: const []);
    return credential?.authorizationCode;
  }

  /// The Apple sheet; null when the user closes it.
  Future<AuthorizationCredentialAppleID?> _appleCredential({
    required List<AppleIDAuthorizationScopes> scopes,
    String? nonce,
  }) async {
    try {
      return await SignInWithApple.getAppleIDCredential(
        scopes: scopes,
        nonce: nonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      rethrow;
    }
  }

  /// Signs out of Google so that the next sign-in shows the account picker.
  ///
  /// Initializes Google first when the app was restarted since the sign-in:
  /// the plugin refuses any call before its initialization.
  Future<void> signOutOfGoogle(GoogleSignInConfig config) async {
    await _initializedGoogle(config);
    await _googleSignIn.signOut();
  }

  /// Whether [error] is an expected failure of the sheet itself (dismissed,
  /// interrupted, no UI to show it, no Apple ID signed in on the device), as
  /// opposed to a misconfiguration.
  static bool isUserSideFailure(Object error) {
    return switch (error) {
      GoogleSignInException(:final code) => const [
          GoogleSignInExceptionCode.canceled,
          GoogleSignInExceptionCode.interrupted,
          GoogleSignInExceptionCode.uiUnavailable,
        ].contains(code),
      SignInWithAppleAuthorizationException(:final code) => const [
          AuthorizationErrorCode.canceled,
          AuthorizationErrorCode.unknown,
        ].contains(code),
      _ => false,
    };
  }

  /// Sentry level of a failed sign-in, null when it is not reported: a sheet
  /// the user closed or a lost connection. A warning for a known cause that
  /// one occurrence does not make a bug, but that must stay visible if it
  /// lasts or spreads: Safari unavailable (WISHY-2), a 502/503/504 (WISHY-6).
  /// An error otherwise, mostly a misconfigured provider or client ID.
  static SentryLevel? sentryLevelOf(Object error) {
    if (isNetworkError(error) || isUserSideFailure(error)) {
      return null;
    }
    if (isSafariUnavailable(error) || isTransientServerError(error)) {
      return SentryLevel.warning;
    }
    return SentryLevel.error;
  }

  static String _generateRawNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String _sha256(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}
