import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/app/config/deeplink_config.dart';

void main() {
  group('DeeplinkConfig.buildWishlistShareUri', () {
    test('builds the public https link of a wishlist', () {
      expect(
        DeeplinkConfig.buildWishlistShareUri(wishlistId: 42).toString(),
        'https://wishy-app.fr/w/42',
      );
    });

    test('round-trips to the wishlist location', () {
      final uri = DeeplinkConfig.buildWishlistShareUri(wishlistId: 42);

      expect(DeeplinkConfig.locationFromUri(uri), '/wishlist/42');
    });
  });

  group('DeeplinkConfig.locationFromUri', () {
    String? locationOf(String link) =>
        DeeplinkConfig.locationFromUri(Uri.parse(link));

    test('opens a shared wishlist link', () {
      expect(locationOf('https://wishy-app.fr/w/42'), '/wishlist/42');
      expect(locationOf('https://wishy-app.fr/w/42/'), '/wishlist/42');
      expect(locationOf('https://wishy-app.fr/w/42?utm=x'), '/wishlist/42');
    });

    test('ignores invalid shared wishlist links', () {
      expect(locationOf('https://wishy-app.fr/w/abc'), isNull);
      expect(locationOf('https://wishy-app.fr/w/0'), isNull);
      expect(locationOf('https://wishy-app.fr/w/-1'), isNull);
      expect(locationOf('https://wishy-app.fr/w/0x10'), isNull);
      expect(locationOf('https://wishy-app.fr/w/42/edit'), isNull);
      expect(locationOf('https://wishy-app.fr/w'), isNull);
      expect(locationOf('https://wishy-app.fr/'), isNull);
    });

    test('ignores links of other hosts and schemes', () {
      expect(locationOf('https://example.com/w/42'), isNull);
      expect(locationOf('http://wishy-app.fr/w/42'), isNull);
      expect(locationOf('https://www.wishy-app.fr/w/42'), isNull);
      expect(locationOf('wishy://other.host/wishlist/42'), isNull);
      expect(locationOf('SharingMedia-com.raphtang.wishy://dataUrl'), isNull);
    });

    test('opens the path of a wishy:// link without its query', () {
      expect(
        locationOf('wishy://com.raphtang.wishy/wishlist/42'),
        '/wishlist/42',
      );
      expect(
        locationOf('wishy://com.raphtang.wishy/auth/reset-password?code=abc'),
        '/auth/reset-password',
      );
      expect(locationOf('wishy://com.raphtang.wishy'), '/');
    });
  });
}
