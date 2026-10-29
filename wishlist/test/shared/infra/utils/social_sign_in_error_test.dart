import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:wishlist/shared/infra/utils/social_sign_in_error.dart';

void main() {
  group('isSafariUnavailable', () {
    test('is true when the Google sheet cannot open Safari', () {
      expect(
        isSafariUnavailable(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.unknownError,
            description: 'Unable to open Safari.',
          ),
        ),
        isTrue,
      );
    });

    test('is false for another Google error or no error', () {
      expect(
        isSafariUnavailable(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.unknownError,
            description: 'Something else',
          ),
        ),
        isFalse,
      );
      expect(
        isSafariUnavailable(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.canceled,
            description: 'Unable to open Safari.',
          ),
        ),
        isFalse,
      );
      expect(isSafariUnavailable(null), isFalse);
    });
  });
}
