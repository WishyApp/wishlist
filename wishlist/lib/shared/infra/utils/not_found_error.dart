import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/app_exception.dart';

/// PostgREST code of a `single()` query that matched no row.
const _noRowFoundCode = 'PGRST116';

/// Whether [error] means that the requested row cannot be found: it does not
/// exist (anymore), or it is hidden from the user by the row level security
/// (a wish whose wishlist became private, a stale link...).
///
/// Looks through [AppException.cause], since repositories wrap the original
/// error.
bool isNotFoundError(Object? error) {
  final cause = error is AppException ? error.cause : error;

  return cause is PostgrestException && cause.code == _noRowFoundCode;
}
