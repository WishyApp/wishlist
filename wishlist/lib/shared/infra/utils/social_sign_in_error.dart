import 'package:google_sign_in/google_sign_in.dart';

/// Whether the Google sheet could not open on iOS: it runs in an
/// `ASWebAuthenticationSession`, which refuses to start when Safari is
/// blocked (Screen Time) or Guided Access is on (WISHY-2, seen on an Apple
/// test device).
///
/// Only the text tells this case apart: AppAuth's
/// `OIDErrorCodeSafariOpenError` reaches Dart as `unknownError`, with nothing
/// but `NSLocalizedDescription` in the details (google_sign_in_ios 6.3.8).
/// If a plugin update rewords it, the generic error is back and the Sentry
/// level goes back to error.
bool isSafariUnavailable(Object? error) =>
    error is GoogleSignInException &&
    error.code == GoogleSignInExceptionCode.unknownError &&
    (error.description?.contains('Unable to open Safari') ?? false);
