import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/utils/postgrest_user_message_key.dart';

void main() {
  group('userMessageKeyForPostgrestException', () {
    test(
        'should return inputTooLong when code is 23514 and message contains '
        '_max_length', () {
      const e = PostgrestException(
        message: 'violation of check constraint "some_max_length"',
        code: '23514',
      );

      expect(
        userMessageKeyForPostgrestException(e),
        AppUserMessageKey.inputTooLong,
      );
    });

    test(
        'should return null when code is 23514 and message does not contain '
        '_max_length', () {
      const e = PostgrestException(
        message: 'other constraint violation',
        code: '23514',
      );

      expect(userMessageKeyForPostgrestException(e), isNull);
    });

    test(
        'should return pseudoAlreadyExists when code is 23505 and message '
        'contains pseudo', () {
      const e = PostgrestException(
        message: 'duplicate key value violates unique constraint '
            '"profiles_pseudo_key"',
        code: '23505',
      );

      expect(
        userMessageKeyForPostgrestException(e),
        AppUserMessageKey.pseudoAlreadyExists,
      );
    });

    test(
        'should return null when code is 23505 and message does not contain '
        'pseudo', () {
      const e = PostgrestException(
        message: 'duplicate key value violates unique constraint "other_key"',
        code: '23505',
      );

      expect(userMessageKeyForPostgrestException(e), isNull);
    });

    test(
        'should return wishOverbooked when code is 23514 and message is '
        'wish_overbooked', () {
      const e = PostgrestException(message: 'wish_overbooked', code: '23514');

      expect(
        userMessageKeyForPostgrestException(e),
        AppUserMessageKey.wishOverbooked,
      );
    });

    test(
        'should return wishQuantityBelowBooked when code is 23514 and message '
        'is wish_quantity_below_booked', () {
      const e = PostgrestException(
        message: 'wish_quantity_below_booked',
        code: '23514',
      );

      expect(
        userMessageKeyForPostgrestException(e),
        AppUserMessageKey.wishQuantityBelowBooked,
      );
    });

    test('should return null when code is null', () {
      const e = PostgrestException(
        message: 'something with _max_length',
      );

      expect(userMessageKeyForPostgrestException(e), isNull);
    });
  });
}
