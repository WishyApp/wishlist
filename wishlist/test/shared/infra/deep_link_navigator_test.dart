import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/infra/deep_link_navigator.dart';

void main() {
  final wishlistLink = Uri.parse('https://wishy-app.fr/w/42');

  test('opens the launch link', () async {
    final controller = StreamController<Uri>.broadcast();
    final locations = <String>[];
    final navigator = DeepLinkNavigator(
      getInitialLink: () async => wishlistLink,
      links: controller.stream,
      navigate: locations.add,
    );

    await navigator.start();

    expect(locations, ['/wishlist/42']);

    await navigator.dispose();
    await controller.close();
  });

  test('opens the links received while running', () async {
    final controller = StreamController<Uri>.broadcast();
    final locations = <String>[];
    final navigator = DeepLinkNavigator(
      getInitialLink: () async => null,
      links: controller.stream,
      navigate: locations.add,
    );

    await navigator.start();
    controller
      ..add(wishlistLink)
      ..add(Uri.parse('wishy://com.raphtang.wishy/wishlist/7'));
    await pumpEventQueue();

    expect(locations, ['/wishlist/42', '/wishlist/7']);

    await navigator.dispose();
    await controller.close();
  });

  test('ignores the links that are not ours', () async {
    final controller = StreamController<Uri>.broadcast();
    final locations = <String>[];
    final navigator = DeepLinkNavigator(
      getInitialLink: () async =>
          Uri.parse('SharingMedia-com.raphtang.wishy://dataUrl=share'),
      links: controller.stream,
      navigate: locations.add,
    );

    await navigator.start();
    controller.add(Uri.parse('https://example.com/w/42'));
    await pumpEventQueue();

    expect(locations, isEmpty);

    await navigator.dispose();
    await controller.close();
  });

  test('keeps listening when the launch link cannot be read', () async {
    final controller = StreamController<Uri>.broadcast();
    final locations = <String>[];
    final navigator = DeepLinkNavigator(
      getInitialLink: () async => throw PlatformException(code: 'error'),
      links: controller.stream,
      navigate: locations.add,
    );

    await navigator.start();
    controller
      ..addError(Exception('stream error'))
      ..add(wishlistLink);
    await pumpEventQueue();

    expect(locations, ['/wishlist/42']);

    await navigator.dispose();
    await controller.close();
  });

  test('stops listening once disposed', () async {
    final controller = StreamController<Uri>.broadcast();
    final locations = <String>[];
    final navigator = DeepLinkNavigator(
      getInitialLink: () async => null,
      links: controller.stream,
      navigate: locations.add,
    );

    await navigator.start();
    await navigator.dispose();
    expect(controller.hasListener, isFalse);

    controller.add(wishlistLink);
    await pumpEventQueue();

    expect(locations, isEmpty);
    await controller.close();
  });
}
