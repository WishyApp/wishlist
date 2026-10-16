import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/app/navigation/sentry_route_name_extractor.dart';

void main() {
  test('drops the route arguments and keeps the name', () {
    final result = sentryRouteNameExtractor(
      const RouteSettings(
        name: '/wishlist/12',
        arguments: {'redirectTo': '/friend/secret'},
      ),
    );

    expect(result?.name, '/wishlist/12');
    expect(result?.arguments, isNull);
  });

  test('returns null without settings', () {
    expect(sentryRouteNameExtractor(null), isNull);
  });
}
