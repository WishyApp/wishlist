import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/user_auth_providers_extension.dart';

void main() {
  User userWith(Map<String, dynamic> appMetadata) => User(
        id: 'id',
        appMetadata: appMetadata,
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      );

  group('UserAuthProvidersExtension.hasPassword', () {
    test('is true for an email account', () {
      expect(
        userWith({
          'providers': ['email'],
        }).hasPassword,
        isTrue,
      );
    });

    test('is true for an email account also linked to Google', () {
      expect(
        userWith({
          'providers': ['email', 'google'],
        }).hasPassword,
        isTrue,
      );
    });

    test('is false for a Google or Apple only account', () {
      expect(
        userWith({
          'providers': ['google'],
        }).hasPassword,
        isFalse,
      );
      expect(
        userWith({
          'providers': ['apple'],
        }).hasPassword,
        isFalse,
      );
    });

    test('is true without the list of providers', () {
      expect(userWith(const {}).hasPassword, isTrue);
    });
  });

  group('UserAuthProvidersExtension.hasAppleSignIn', () {
    test('is true when Apple is among the providers', () {
      expect(
        userWith({
          'providers': ['email', 'apple'],
        }).hasAppleSignIn,
        isTrue,
      );
    });

    test('is false otherwise', () {
      expect(
        userWith({
          'providers': ['google'],
        }).hasAppleSignIn,
        isFalse,
      );
      expect(userWith(const {}).hasAppleSignIn, isFalse);
    });
  });
}
