import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/app_exception.dart';

/// Whether [error] comes from a missing or too slow network rather than from
/// the server: no connection, DNS or TLS failure, request timeout...
///
/// Looks through [AppException.cause], since repositories wrap the original
/// error.
bool isNetworkError(Object? error) {
  return switch (unwrapCause(error)) {
    // SocketException, HttpException, TlsException (captive portals...)
    IOException() || TimeoutException() || http.ClientException() => true,
    // Also thrown on 5xx responses, which then carry their status code
    AuthRetryableFetchException(:final statusCode) => statusCode == null,
    _ => false,
  };
}

/// Statuses of a gateway in front of a server that restarts or is overloaded.
/// Not 500 or 501: a bug or a misconfiguration returns them on every call.
const _transientStatuses = {502, 503, 504};

/// PostgREST's own 503 (database unreachable) and 504 (pool timeout):
/// https://docs.postgrest.org/en/stable/references/errors.html
const _transientPostgrestCodes = {
  'PGRST000',
  'PGRST001',
  'PGRST002',
  'PGRST003',
};

/// Whether [error] is a 502, 503 or 504 from the server or its gateway:
/// passing, like a missing network, so a retry has a chance and a single one
/// is not worth a Sentry report.
///
/// Looks through [AppException.cause]. Its [AppException.statusCode] is not
/// used: it is 500 for anything but a numeric PostgREST code.
bool isTransientServerError(Object? error) {
  final status = switch (unwrapCause(error)) {
    PostgrestException(:final code)
        when _transientPostgrestCodes.contains(code) =>
      503,
    // A non-JSON body (gateway) leaves the HTTP status in the code
    PostgrestException(:final code) => int.tryParse(code ?? ''),
    AuthRetryableFetchException(:final statusCode) =>
      int.tryParse(statusCode ?? ''),
    StorageException(:final statusCode) => int.tryParse(statusCode ?? ''),
    _ => null,
  };
  return _transientStatuses.contains(status);
}
