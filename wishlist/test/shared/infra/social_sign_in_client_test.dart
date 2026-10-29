import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/app/config/config.dart';
import 'package:wishlist/shared/infra/social_sign_in_client.dart';

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

// ignore: avoid_implementing_value_types
class _MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

void main() {
  const config = GoogleSignInConfig(webClientId: 'web');

  late _MockGoogleSignIn googleSignIn;
  late _MockGoogleSignInAccount account;
  late SocialSignInClient client;
  String? hashedNonce;

  void stubInitialize() {
    when(
      () => googleSignIn.initialize(
        clientId: any(named: 'clientId'),
        serverClientId: any(named: 'serverClientId'),
        nonce: any(named: 'nonce'),
      ),
    ).thenAnswer((invocation) async {
      hashedNonce = invocation.namedArguments[#nonce] as String?;
    });
  }

  setUp(() {
    googleSignIn = _MockGoogleSignIn();
    account = _MockGoogleSignInAccount();
    hashedNonce = null;
    stubInitialize();
    when(() => googleSignIn.authenticate()).thenAnswer((_) async => account);
    when(() => googleSignIn.signOut()).thenAnswer((_) async {});
    when(() => account.authentication)
        .thenReturn(const GoogleSignInAuthentication(idToken: 'id-token'));
    client = SocialSignInClient(googleSignIn: googleSignIn);
  });

  group('SocialSignInClient.googleIdToken', () {
    test('gives Google the SHA-256 of the raw nonce it returns', () async {
      final token = await client.googleIdToken(config);

      expect(token?.idToken, 'id-token');
      expect(
        hashedNonce,
        sha256.convert(utf8.encode(token!.rawNonce)).toString(),
      );
      verify(
        () => googleSignIn.initialize(
          serverClientId: 'web',
          nonce: any(named: 'nonce'),
        ),
      ).called(1);
    });

    test('initializes Google once and keeps the nonce', () async {
      final first = await client.googleIdToken(config);
      final second = await client.googleIdToken(config);

      expect(second?.rawNonce, first?.rawNonce);
      verify(
        () => googleSignIn.initialize(
          clientId: any(named: 'clientId'),
          serverClientId: any(named: 'serverClientId'),
          nonce: any(named: 'nonce'),
        ),
      ).called(1);
    });

    test('initializes again after a failed initialization', () async {
      when(
        () => googleSignIn.initialize(
          clientId: any(named: 'clientId'),
          serverClientId: any(named: 'serverClientId'),
          nonce: any(named: 'nonce'),
        ),
      ).thenThrow(Exception('no Play services'));

      await expectLater(client.googleIdToken(config), throwsException);

      stubInitialize();
      expect(await client.googleIdToken(config), isNotNull);
    });

    test('returns null when the user dismisses the sheet', () async {
      when(() => googleSignIn.authenticate()).thenThrow(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      );

      expect(await client.googleIdToken(config), isNull);
    });

    test('propagates a configuration error', () async {
      when(() => googleSignIn.authenticate()).thenThrow(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
        ),
      );

      await expectLater(
        client.googleIdToken(config),
        throwsA(isA<GoogleSignInException>()),
      );
    });

    test('throws when Google returns no ID token', () async {
      when(() => account.authentication)
          .thenReturn(const GoogleSignInAuthentication(idToken: null));

      await expectLater(
        client.googleIdToken(config),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('SocialSignInClient.signOutOfGoogle', () {
    test('signs out of Google after a sign-in', () async {
      await client.googleIdToken(config);
      await client.signOutOfGoogle(config);

      verify(() => googleSignIn.signOut()).called(1);
    });

    test('initializes Google first after a restart of the app', () async {
      // A new client on a fresh GoogleSignIn: nothing initialized yet.
      await client.signOutOfGoogle(config);

      verify(
        () => googleSignIn.initialize(
          serverClientId: 'web',
          nonce: any(named: 'nonce'),
        ),
      ).called(1);
      verify(() => googleSignIn.signOut()).called(1);
    });

    test('shares the initialization between clients', () async {
      await client.googleIdToken(config);
      await SocialSignInClient(googleSignIn: googleSignIn)
          .signOutOfGoogle(config);

      verify(
        () => googleSignIn.initialize(
          clientId: any(named: 'clientId'),
          serverClientId: any(named: 'serverClientId'),
          nonce: any(named: 'nonce'),
        ),
      ).called(1);
    });
  });

  group('SocialSignInClient.sentryLevelOf', () {
    const safariUnavailable = GoogleSignInException(
      code: GoogleSignInExceptionCode.unknownError,
      description: 'Unable to open Safari.',
      details: {'NSLocalizedDescription': 'Unable to open Safari.'},
    );

    test('reports a misconfiguration as an error', () {
      expect(
        SocialSignInClient.sentryLevelOf(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.clientConfigurationError,
          ),
        ),
        SentryLevel.error,
      );
      expect(
        SocialSignInClient.sentryLevelOf(
          const AuthApiException('Bad ID token', statusCode: '400'),
        ),
        SentryLevel.error,
      );
    });

    test('reports a 502, 503 or 504 as a warning', () {
      for (final status in ['502', '503', '504']) {
        expect(
          SocialSignInClient.sentryLevelOf(
            AuthRetryableFetchException(statusCode: status),
          ),
          SentryLevel.warning,
          reason: status,
        );
      }
    });

    test('reports another 5xx as an error', () {
      expect(
        SocialSignInClient.sentryLevelOf(
          AuthRetryableFetchException(statusCode: '500'),
        ),
        SentryLevel.error,
      );
    });

    test('reports Safari unavailable as a warning', () {
      expect(
        SocialSignInClient.sentryLevelOf(safariUnavailable),
        SentryLevel.warning,
      );
    });

    test('skips a lost connection', () {
      for (final error in <Object>[
        AuthRetryableFetchException(),
        const SocketException('Network is unreachable'),
        TimeoutException('No event received'),
      ]) {
        expect(
          SocialSignInClient.sentryLevelOf(error),
          isNull,
          reason: '$error',
        );
      }
    });

    test('skips a closed or interrupted sheet', () {
      for (final code in [
        GoogleSignInExceptionCode.canceled,
        GoogleSignInExceptionCode.interrupted,
      ]) {
        expect(
          SocialSignInClient.sentryLevelOf(GoogleSignInException(code: code)),
          isNull,
          reason: '$code',
        );
      }
      expect(
        SocialSignInClient.sentryLevelOf(
          const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.canceled,
            message: '',
          ),
        ),
        isNull,
      );
    });
  });

  group('SocialSignInClient.isSafariUnavailable', () {
    test('is true when the Google sheet cannot open Safari', () {
      const error = GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'Unable to open Safari.',
      );

      expect(SocialSignInClient.isSafariUnavailable(error), isTrue);
    });

    test('is false for another unknown Google error', () {
      const error = GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'Something else',
      );

      expect(SocialSignInClient.isSafariUnavailable(error), isFalse);
    });
  });

  group('SocialSignInClient.isUserSideFailure', () {
    test('is true for a dismissed or interrupted sheet', () {
      for (final code in [
        GoogleSignInExceptionCode.canceled,
        GoogleSignInExceptionCode.interrupted,
        GoogleSignInExceptionCode.uiUnavailable,
      ]) {
        expect(
          SocialSignInClient.isUserSideFailure(
            GoogleSignInException(code: code),
          ),
          isTrue,
        );
      }
    });

    test('is true for a dismissed Apple sheet or no Apple ID signed in', () {
      for (final code in [
        AuthorizationErrorCode.canceled,
        AuthorizationErrorCode.unknown,
      ]) {
        expect(
          SocialSignInClient.isUserSideFailure(
            SignInWithAppleAuthorizationException(code: code, message: ''),
          ),
          isTrue,
        );
      }
      expect(
        SocialSignInClient.isUserSideFailure(
          const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.failed,
            message: '',
          ),
        ),
        isFalse,
      );
    });

    test('is false for a misconfiguration', () {
      expect(
        SocialSignInClient.isUserSideFailure(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.clientConfigurationError,
          ),
        ),
        isFalse,
      );
      expect(SocialSignInClient.isUserSideFailure(Exception()), isFalse);
    });
  });
}
