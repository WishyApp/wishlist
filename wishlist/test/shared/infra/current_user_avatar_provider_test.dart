import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/shared/infra/avatar_service.dart';
import 'package:wishlist/shared/infra/current_user_avatar_provider.dart';

class MockAvatarService extends Mock implements AvatarService {}

const _idle = AsyncValue<void>.data(null);

void main() {
  late MockAvatarService avatarService;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(File('avatar.png'));
  });

  setUp(() {
    avatarService = MockAvatarService();
    container = ProviderContainer(
      overrides: [avatarServiceProvider.overrideWithValue(avatarService)],
    );
    addTearDown(container.dispose);
  });

  test('is idle at start and loads nothing', () {
    container.listen(avatarEditProvider, (_, __) {});

    expect(container.read(avatarEditProvider), _idle);
    verifyNever(() => avatarService.getAvatarUrl(any()));
  });

  test('is loading during an upload then idle again', () async {
    final upload = Completer<String>();
    when(() => avatarService.uploadAvatar(any()))
        .thenAnswer((_) => upload.future);
    container.listen(avatarEditProvider, (_, __) {});

    final pending = container
        .read(avatarEditProvider.notifier)
        .uploadAvatar(File('avatar.png'));
    expect(container.read(avatarEditProvider).isLoading, isTrue);

    upload.complete('path');
    await pending;

    expect(container.read(avatarEditProvider), _idle);
  });

  test('exposes the error of a failing upload', () async {
    when(() => avatarService.uploadAvatar(any()))
        .thenThrow(Exception('network'));
    container.listen(avatarEditProvider, (_, __) {});

    await container
        .read(avatarEditProvider.notifier)
        .uploadAvatar(File('avatar.png'));

    expect(container.read(avatarEditProvider).hasError, isTrue);
  });

  test('is loading during a delete then idle again', () async {
    final delete = Completer<void>();
    when(() => avatarService.deleteAvatar()).thenAnswer((_) => delete.future);
    container.listen(avatarEditProvider, (_, __) {});

    final pending = container.read(avatarEditProvider.notifier).deleteAvatar();
    expect(container.read(avatarEditProvider).isLoading, isTrue);

    delete.complete();
    await pending;

    expect(container.read(avatarEditProvider), _idle);
  });

  group('when the notifier is disposed during an async call', () {
    test('an upload still runs to the end and finishing late does not throw',
        () async {
      final upload = Completer<String>();
      when(() => avatarService.uploadAvatar(any()))
          .thenAnswer((_) => upload.future);

      final subscription = container.listen(avatarEditProvider, (_, __) {});
      final pending = container
          .read(avatarEditProvider.notifier)
          .uploadAvatar(File('avatar.png'));
      subscription.close();
      await pumpEventQueue();

      upload.complete('path');
      await pending;

      verify(() => avatarService.uploadAvatar(any())).called(1);
    });

    test('a failing upload finishing late does not throw', () async {
      final upload = Completer<String>();
      when(() => avatarService.uploadAvatar(any()))
          .thenAnswer((_) => upload.future);

      final subscription = container.listen(avatarEditProvider, (_, __) {});
      final pending = container
          .read(avatarEditProvider.notifier)
          .uploadAvatar(File('avatar.png'));
      subscription.close();
      await pumpEventQueue();

      upload.completeError(Exception('network'));
      await pending;
    });

    test('a delete finishing late does not throw', () async {
      final delete = Completer<void>();
      when(() => avatarService.deleteAvatar()).thenAnswer((_) => delete.future);

      final subscription = container.listen(avatarEditProvider, (_, __) {});
      final pending =
          container.read(avatarEditProvider.notifier).deleteAvatar();
      subscription.close();
      await pumpEventQueue();

      delete.complete();
      await pending;
    });
  });
}
