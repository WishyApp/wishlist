import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/app_exception.dart';

/// Whether [error] comes from a missing or too slow network rather than from
/// the server: no connection, DNS failure, request timeout...
///
/// Looks through [AppException.cause], since repositories wrap the original
/// error.
bool isNetworkError(Object? error) {
  final cause = error is AppException ? error.cause : error;

  return cause is SocketException ||
      cause is TimeoutException ||
      cause is http.ClientException ||
      cause is AuthRetryableFetchException;
}
