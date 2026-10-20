import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/app/dev/store_screenshot_mode.dart';

void main() {
  test('store screenshot mode is disabled without the dart-define', () {
    expect(StoreScreenshotMode.enabled, isFalse);
  });
}
