import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/shared/infra/avatar_service.dart';
import 'package:wishlist/shared/infra/current_user_avatar_provider.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/models/app_user.dart';
import 'package:wishlist/shared/models/profile.dart';

import '../../fixtures/fake_data.dart';
import '../../fixtures/mock_supabase.dart';

class MockAvatarService extends Mock implements AvatarService {}

AppUser _appUserFor(String userId) => AppUser(
      profile: Profile(
        id: userId,
        pseudo: 'pseudo',
        avatarUrl: 'path-$userId',
      ),
      user: fakeCurrentAppUser.user,
    );

void main() {
  late FakeAuthSession session;
  late MockUserService userService;
  late MockAvatarService avatarService;
  late ProviderContainer container;

  void signIn(String userId) => session.signIn(userId);

  setUpAll(() {
    registerFallbackValue(File('avatar.png'));
  });

  setUp(() {
    session = FakeAuthSession();
    addTearDown(session.close);
    userService = MockUserService();
    when(() => userService.getAppUserById(any())).thenAnswer(
      (invocation) async =>
          _appUserFor(invocation.positionalArguments.first as String),
    );
    avatarService = MockAvatarService();
    when(() => avatarService.getAvatarUrl(any()))
        .thenAnswer((i) => 'url-${i.positionalArguments.first}');

    container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(session.client),
        userServiceProvider.overrideWithValue(userService),
        avatarServiceProvider.overrideWithValue(avatarService),
      ],
    );
    addTearDown(container.dispose);
  });

  test('loads the avatar of the signed-in user', () async {
    signIn('user-1');
    container.listen(currentUserAvatarProvider, (_, __) {});
    await pumpEventQueue();

    verify(() => userService.getAppUserById('user-1')).called(1);
    expect(
      container.read(currentUserAvatarProvider),
      const AsyncValue<String?>.data('url-path-user-1'),
    );
  });

  test('has no avatar and loads nothing without a session', () async {
    container.listen(currentUserAvatarProvider, (_, __) {});
    await pumpEventQueue();

    expect(
      container.read(currentUserAvatarProvider),
      const AsyncValue<String?>.data(null),
    );
    verifyNever(() => userService.getAppUserById(any()));
  });

  test('is rebuilt for the new user once its listeners are gone', () async {
    signIn('user-1');
    final subscription =
        container.listen(currentUserAvatarProvider, (_, __) {});
    await pumpEventQueue();
    subscription.close();
    await pumpEventQueue();

    signIn('user-2');
    container.listen(currentUserAvatarProvider, (_, __) {});
    await pumpEventQueue();

    verify(() => userService.getAppUserById('user-2')).called(1);
    expect(
      container.read(currentUserAvatarProvider),
      const AsyncValue<String?>.data('url-path-user-2'),
    );
  });

  group('when the notifier is disposed during an async call', () {
    test('a load finishing late does not throw nor touch the new user',
        () async {
      final firstLoad = Completer<AppUser>();
      signIn('user-1');
      when(() => userService.getAppUserById('user-1'))
          .thenAnswer((_) => firstLoad.future);

      final subscription =
          container.listen(currentUserAvatarProvider, (_, __) {});
      await pumpEventQueue();
      subscription.close();
      await pumpEventQueue();

      signIn('user-2');
      container.listen(currentUserAvatarProvider, (_, __) {});
      await pumpEventQueue();

      firstLoad.complete(_appUserFor('user-1'));
      await pumpEventQueue();

      expect(
        container.read(currentUserAvatarProvider),
        const AsyncValue<String?>.data('url-path-user-2'),
      );
    });

    test('a failing load finishing late does not throw', () async {
      final firstLoad = Completer<AppUser>();
      signIn('user-1');
      when(() => userService.getAppUserById('user-1'))
          .thenAnswer((_) => firstLoad.future);

      final subscription =
          container.listen(currentUserAvatarProvider, (_, __) {});
      await pumpEventQueue();
      subscription.close();
      await pumpEventQueue();

      firstLoad.completeError(Exception('network'));
      await pumpEventQueue();
    });

    test('an upload finishing late does not throw', () async {
      final upload = Completer<String>();
      signIn('user-1');
      when(() => avatarService.uploadAvatar(any()))
          .thenAnswer((_) => upload.future);

      final subscription =
          container.listen(currentUserAvatarProvider, (_, __) {});
      await pumpEventQueue();
      final pending = container
          .read(currentUserAvatarProvider.notifier)
          .uploadAvatar(File('avatar.png'));
      subscription.close();
      await pumpEventQueue();

      upload.complete('path');
      await pending;
    });

    test('a delete finishing late does not throw', () async {
      final delete = Completer<void>();
      signIn('user-1');
      when(() => avatarService.deleteAvatar()).thenAnswer((_) => delete.future);

      final subscription =
          container.listen(currentUserAvatarProvider, (_, __) {});
      await pumpEventQueue();
      final pending =
          container.read(currentUserAvatarProvider.notifier).deleteAvatar();
      subscription.close();
      await pumpEventQueue();

      delete.complete();
      await pending;
    });
  });
}
