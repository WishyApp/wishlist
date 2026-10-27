import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/app/config/config.dart';

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

  /// google_sign_in takes its nonce once, at initialization: the raw nonce
  /// lives as long as the app, so every Google token of a run carries the
  /// same one: it ties a token to this run of the app, not to one attempt.
  Future<String>? _googleRawNonce;

  Future<SocialIdToken?> googleIdToken(GoogleSignInConfig config) async {
    final initialization = _googleRawNonce ??= _initializeGoogle(config);
    final String rawNonce;
    try {
      rawNonce = await initialization;
    } catch (_) {
      // Let the next attempt initialize again.
      if (identical(_googleRawNonce, initialization)) {
        _googleRawNonce = null;
      }
      rethrow;
    }

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
      clientId: config.iosClientId,
      serverClientId: config.webClientId,
      nonce: _sha256(rawNonce),
    );
    return rawNonce;
  }

  Future<SocialIdToken?> appleIdToken() async {
    final rawNonce = _generateRawNonce();

    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
        nonce: _sha256(rawNonce),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      rethrow;
    }

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple returned no ID token');
    }

    return SocialIdToken(idToken: idToken, rawNonce: rawNonce);
  }

  /// Signs out of Google so that the next sign-in shows the account picker.
  Future<void> signOutOfGoogle() async {
    final initialization = _googleRawNonce;
    if (initialization == null) {
      return;
    }
    await initialization;
    await _googleSignIn.signOut();
  }

  /// Whether [error] is an expected failure of the sheet itself (dismissed,
  /// interrupted, no UI to show it), as opposed to a misconfiguration.
  static bool isUserSideFailure(Object error) {
    return error is GoogleSignInException &&
        const [
          GoogleSignInExceptionCode.canceled,
          GoogleSignInExceptionCode.interrupted,
          GoogleSignInExceptionCode.uiUnavailable,
        ].contains(error.code);
  }

  static String _generateRawNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String _sha256(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}
