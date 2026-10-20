import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/widgets/text_form_fields/validators/password_validator.dart';

void main() {
  group('PasswordValidator', () {
    test('minimum length is 8, aligned with supabase/config.toml', () {
      expect(PasswordValidator.minLength, 8);
    });

    test('hasMinLength rejects 7 characters and accepts 8', () {
      expect(PasswordValidator.hasMinLength('Abcde1!'), isFalse);
      expect(PasswordValidator.hasMinLength('Abcdef1!'), isTrue);
    });

    test('hasMinLength ignores surrounding whitespace, trimmed on submit', () {
      expect(PasswordValidator.hasMinLength(' Abcde1! '), isFalse);
      expect(PasswordValidator.isValid('Abcde1! '), isFalse);
    });

    test('isValid rejects null, empty and 6-7 character passwords', () {
      expect(PasswordValidator.isValid(null), isFalse);
      expect(PasswordValidator.isValid(''), isFalse);
      expect(PasswordValidator.isValid('Abc1!x'), isFalse);
      expect(PasswordValidator.isValid('Abcd1!x'), isFalse);
    });

    test('isValid accepts a password meeting every requirement', () {
      expect(PasswordValidator.isValid('Abcdef1!'), isTrue);
    });

    test('isValid rejects a long password missing a character class', () {
      expect(PasswordValidator.isValid('abcdefgh1!'), isFalse);
      expect(PasswordValidator.isValid('ABCDEFGH1!'), isFalse);
      expect(PasswordValidator.isValid('Abcdefgh!!'), isFalse);
      expect(PasswordValidator.isValid('Abcdefgh12'), isFalse);
    });
  });
}
