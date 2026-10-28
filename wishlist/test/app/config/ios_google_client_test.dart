import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Google sheet comes back to the app through a URL scheme derived from
/// the iOS client ID: if they differ, tapping Google crashes the app.
void main() {
  test('Info.plist declares the reversed GIDClientID as a URL scheme', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    final clientId = RegExp(
      r'<key>GIDClientID</key>\s*<string>([^<]+)</string>',
    ).firstMatch(plist)?.group(1);
    expect(clientId, isNotNull, reason: 'GIDClientID missing');

    const suffix = '.apps.googleusercontent.com';
    expect(clientId, endsWith(suffix));
    final reversed = 'com.googleusercontent.apps.'
        '${clientId!.substring(0, clientId.length - suffix.length)}';

    expect(plist, contains('<string>$reversed</string>'));
  });
}
