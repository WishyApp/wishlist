import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/utils/network_error.dart';

void main() {
  group('isNetworkError', () {
    test('recognizes the errors of a missing or slow network', () {
      expect(isNetworkError(const SocketException('Failed host lookup')), true);
      expect(isNetworkError(TimeoutException('No event received')), true);
      expect(isNetworkError(http.ClientException('Connection closed')), true);
      expect(isNetworkError(AuthRetryableFetchException()), true);
      expect(
        isNetworkError(const HandshakeException('Handshake error')),
        true,
      );
      expect(isNetworkError(const HttpException('Connection closed')), true);
    });

    test('looks through the AppException wrapping the original error', () {
      final error = AppException(
        statusCode: 500,
        message: 'Failed to fetch wishlists',
        cause: const SocketException('Network is unreachable'),
      );

      expect(isNetworkError(error), true);
    });

    test('rejects server and unknown errors', () {
      expect(
        isNetworkError(const PostgrestException(message: 'boom', code: '500')),
        false,
      );
      expect(
        isNetworkError(
          AppException(
            statusCode: 500,
            cause: const PostgrestException(message: 'boom'),
          ),
        ),
        false,
      );
      expect(
        isNetworkError(AuthRetryableFetchException(statusCode: '503')),
        false,
      );
      expect(isNetworkError(AppException(statusCode: 500)), false);
      expect(isNetworkError(Exception('boom')), false);
      expect(isNetworkError(null), false);
    });
  });

  group('isTransientServerError', () {
    test('recognizes a 502, 503 or 504, wrapped or not', () {
      for (final status in ['502', '503', '504']) {
        expect(
          isTransientServerError(PostgrestException(message: '', code: status)),
          true,
          reason: status,
        );
        expect(
          isTransientServerError(
            AppException(
              statusCode: int.parse(status),
              cause: PostgrestException(message: '', code: status),
            ),
          ),
          true,
          reason: status,
        );
        expect(
          isTransientServerError(
            AuthRetryableFetchException(statusCode: status),
          ),
          true,
          reason: status,
        );
        expect(
          isTransientServerError(
            StorageException('', statusCode: status),
          ),
          true,
          reason: status,
        );
      }
    });

    test("recognizes PostgREST's own 503 and 504", () {
      for (final code in ['PGRST000', 'PGRST001', 'PGRST002', 'PGRST003']) {
        expect(
          isTransientServerError(PostgrestException(message: '', code: code)),
          true,
          reason: code,
        );
      }
    });

    test('rejects other statuses and codes', () {
      for (final code in ['499', '500', '501', '505', '599', 'PGRST202']) {
        expect(
          isTransientServerError(PostgrestException(message: '', code: code)),
          false,
          reason: code,
        );
      }
      expect(isTransientServerError(AuthRetryableFetchException()), false);
      expect(isTransientServerError(AppException(statusCode: 503)), false);
      expect(
        isTransientServerError(const SocketException('Network is down')),
        false,
      );
      expect(isTransientServerError(null), false);
    });
  });
}
