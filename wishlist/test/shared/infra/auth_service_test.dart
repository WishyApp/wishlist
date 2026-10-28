import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/app/config/config.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/auth_service.dart';
import 'package:wishlist/shared/infra/social_sign_in_client.dart';

import '../../fixtures/mock_supabase.dart';

class MockSocialSignInClient extends Mock implements SocialSignInClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(UserAttributes());
    registerFallbackValue(OAuthProvider.google);
    registerFallbackValue(const GoogleSignInConfig(webClientId: 'web'));
  });

  late MockGoTrueClient auth;
  late MockSocialSignInClient socialSignIn;
  late MockUser user;
  late AuthService service;

  setUp(() {
    auth = MockGoTrueClient();
    user = MockUser();
    when(() => user.email).thenReturn('me@example.com');
    when(() => auth.currentUser).thenReturn(user);
    socialSignIn = MockSocialSignInClient();
    service = AuthService(
      auth: auth,
      socialSignIn: socialSignIn,
      googleSignInConfig: const GoogleSignInConfig(webClientId: 'web'),
    );
  });

  void stubSignIn(Object error) {
    when(
      () => auth.signInWithPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(error);
  }

  const invalidCredentials = AuthApiException(
    'Invalid login credentials',
    statusCode: '400',
    code: 'invalid_credentials',
  );

  final networkError = AuthRetryableFetchException(
    message: 'ClientException with SocketException: Failed host lookup',
  );
  final rateLimited = AuthApiException(
    'Too many requests',
    statusCode: '429',
    code: ErrorCode.overRequestRateLimit.code,
  );

  group('AuthService.confirmPasswordIsCorrect', () {
    test('returns true when the sign-in succeeds', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => AuthResponse());

      expect(await service.confirmPasswordIsCorrect('pwd'), isTrue);
    });

    test('returns false for invalid credentials', () async {
      stubSignIn(invalidCredentials);

      expect(await service.confirmPasswordIsCorrect('bad'), isFalse);
    });

    test('returns false for invalid credentials without error code', () async {
      stubSignIn(
        const AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
        ),
      );

      expect(await service.confirmPasswordIsCorrect('bad'), isFalse);
    });

    test('propagates a network error', () async {
      stubSignIn(networkError);

      await expectLater(
        service.confirmPasswordIsCorrect('pwd'),
        throwsA(same(networkError)),
      );
    });

    test('propagates a rate limit error', () async {
      stubSignIn(rateLimited);

      await expectLater(
        service.confirmPasswordIsCorrect('pwd'),
        throwsA(same(rateLimited)),
      );
    });

    test('propagates a server error', () async {
      stubSignIn(
        const AuthApiException(
          'Internal error',
          statusCode: '500',
          code: 'unexpected_failure',
        ),
      );

      await expectLater(
        service.confirmPasswordIsCorrect('pwd'),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('AuthService.changePassword', () {
    test('reports an incorrect old password with its user message', () async {
      stubSignIn(invalidCredentials);

      await expectLater(
        service.changePassword(oldPassword: 'bad', newPassword: 'new'),
        throwsA(
          isA<AppException>().having(
            (e) => e.userMessageKey,
            'userMessageKey',
            AppUserMessageKey.oldPasswordIncorrect,
          ),
        ),
      );
    });

    for (final entry in {
      'a network error': networkError,
      'a rate limit error': rateLimited,
    }.entries) {
      test('turns ${entry.key} into a generic AppException', () async {
        stubSignIn(entry.value);

        await expectLater(
          service.changePassword(oldPassword: 'pwd', newPassword: 'new'),
          throwsA(
            isA<AppException>()
                .having((e) => e.userMessageKey, 'userMessageKey', isNull)
                .having((e) => e.cause, 'cause', same(entry.value)),
          ),
        );
        verifyNever(() => auth.updateUser(any()));
      });
    }
  });

  group('AuthService network errors keep their cause', () {
    void stubUpdateUser(Object error) {
      when(() => auth.updateUser(any())).thenThrow(error);
    }

    test('changePassword, on the updateUser step', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => AuthResponse());
      stubUpdateUser(networkError);

      await expectLater(
        service.changePassword(oldPassword: 'pwd', newPassword: 'new'),
        throwsA(
          isA<AppException>().having((e) => e.cause, 'cause', networkError),
        ),
      );
    });

    test('resetPassword', () async {
      stubUpdateUser(networkError);

      await expectLater(
        service.resetPassword(newPassword: 'new'),
        throwsA(
          isA<AppException>().having((e) => e.cause, 'cause', networkError),
        ),
      );
    });

    test('sendPasswordResetEmail', () async {
      when(
        () => auth.resetPasswordForEmail(
          any(),
          redirectTo: any(named: 'redirectTo'),
        ),
      ).thenThrow(networkError);

      await expectLater(
        service.sendPasswordResetEmail(email: 'me@example.com'),
        throwsA(
          isA<AppException>().having((e) => e.cause, 'cause', networkError),
        ),
      );
    });
  });

  group('social sign-in', () {
    const googleConfig = GoogleSignInConfig(webClientId: 'web');
    const token = SocialIdToken(idToken: 'id-token', rawNonce: 'raw-nonce');

    void stubSignInWithIdToken() {
      when(
        () => auth.signInWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          nonce: any(named: 'nonce'),
        ),
      ).thenAnswer((_) async => AuthResponse());
    }

    test('Google: signs in to Supabase with the ID token and raw nonce',
        () async {
      when(() => socialSignIn.googleIdToken(googleConfig))
          .thenAnswer((_) async => token);
      stubSignInWithIdToken();

      expect(await service.signInWithGoogle(), isTrue);

      verify(
        () => auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: 'id-token',
          nonce: 'raw-nonce',
        ),
      ).called(1);
    });

    test('Google: does nothing when the user dismisses the sheet', () async {
      when(() => socialSignIn.googleIdToken(any()))
          .thenAnswer((_) async => null);

      expect(await service.signInWithGoogle(), isFalse);

      verifyNever(
        () => auth.signInWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          nonce: any(named: 'nonce'),
        ),
      );
    });

    test('Apple: signs in to Supabase with the ID token and raw nonce',
        () async {
      when(() => socialSignIn.appleIdToken()).thenAnswer((_) async => token);
      stubSignInWithIdToken();

      expect(await service.signInWithApple(), isTrue);

      verify(
        () => auth.signInWithIdToken(
          provider: OAuthProvider.apple,
          idToken: 'id-token',
          nonce: 'raw-nonce',
        ),
      ).called(1);
    });

    test('Apple: does nothing when the user dismisses the sheet', () async {
      when(() => socialSignIn.appleIdToken()).thenAnswer((_) async => null);

      expect(await service.signInWithApple(), isFalse);

      verifyNever(
        () => auth.signInWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          nonce: any(named: 'nonce'),
        ),
      );
    });

    test('propagates a Supabase rejection of the token', () async {
      when(() => socialSignIn.appleIdToken()).thenAnswer((_) async => token);
      when(
        () => auth.signInWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          nonce: any(named: 'nonce'),
        ),
      ).thenThrow(const AuthApiException('Bad ID token', statusCode: '400'));

      await expectLater(
        service.signInWithApple(),
        throwsA(isA<AuthApiException>()),
      );
    });
  });

  group('AuthService.signOut', () {
    const config = GoogleSignInConfig(webClientId: 'web');

    setUp(() {
      when(() => auth.signOut()).thenAnswer((_) async {});
      when(() => socialSignIn.signOutOfGoogle(config)).thenAnswer((_) async {});
    });

    test('signs out of Google too for a Google account', () async {
      when(() => user.appMetadata).thenReturn({
        'providers': ['google'],
      });

      await service.signOut(_FakeContext(), _FakeRef());

      verify(() => auth.signOut()).called(1);
      verify(() => socialSignIn.signOutOfGoogle(config)).called(1);
    });

    test('leaves Google alone for an email account', () async {
      when(() => user.appMetadata).thenReturn({
        'providers': ['email'],
      });

      await service.signOut(_FakeContext(), _FakeRef());

      verifyNever(() => socialSignIn.signOutOfGoogle(any()));
    });

    test('still signs out when Google fails', () async {
      when(() => user.appMetadata).thenReturn({
        'providers': ['google'],
      });
      when(() => socialSignIn.signOutOfGoogle(config))
          .thenThrow(Exception('Play services missing'));

      await service.signOut(_FakeContext(), _FakeRef());

      verify(() => auth.signOut()).called(1);
    });
  });
}

class _FakeContext extends Fake implements BuildContext {}

class _FakeRef extends Fake implements WidgetRef {}
