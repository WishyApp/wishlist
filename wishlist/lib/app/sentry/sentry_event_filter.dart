import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Refresh token errors Supabase already handles by ending the session: the
/// user lands on the sign-in screen and signs in again. Typical after a
/// session restored from an old copy (WISHY-3) or refreshed twice at once.
const _expectedSessionLossCodes = {
  'refresh_token_already_used',
  'refresh_token_not_found',
};

/// Whether [error] is an expected loss of the session, not worth a report.
bool isExpectedSessionLoss(Object? error) =>
    error is AuthApiException && _expectedSessionLossCodes.contains(error.code);

/// `beforeSend` of Sentry: drops the expected errors, keeps the others.
SentryEvent? dropExpectedErrors(SentryEvent event, Hint hint) =>
    isExpectedSessionLoss(event.throwable) ? null : event;
