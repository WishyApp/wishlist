import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/avatar_service.dart';
import 'package:wishlist/shared/infra/current_user_avatar_provider.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/models/app_user.dart';
import 'package:wishlist/shared/models/profile.dart';

import '../../fixtures/fake_data.dart';
import '../../fixtures/mock_supabase.dart';

class MockAvatarService extends Mock implements AvatarService {}

// ignore: avoid_implementing_value_types
class MockSession extends Mock implements Session {}

Session _sessionFor(String userId) {
  final user = MockUser();
  when(() => user.id).thenReturn(userId);
  final session = MockSession();
  when(() => session.user).thenReturn(user);
  return session;
}

Future<void> _pump() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late BehaviorSubject<AuthState> authEvents;
  late MockGoTrueClient auth;
  late MockUserService userService;
  late ProviderContainer container;
  late User? currentUser;

  void signIn(String userId) {
    final session = _sessionFor(userId);
    currentUser = session.user;
    authEvents.add(AuthState(AuthChangeEvent.signedIn, session));
  }

  setUp(() {
    // Like gotrue, replays its last event to every new subscriber.
    authEvents = BehaviorSubject<AuthState>();
    currentUser = null;
    final client = MockSupabaseClient();
    auth = MockGoTrueClient();
    when(() => client.auth).thenReturn(auth);
    when(() => auth.onAuthStateChange).thenAnswer((_) => authEvents);
    when(() => auth.currentUser).thenAnswer((_) => currentUser);
    userService = MockUserService();
    when(userService.getCurrentUserId).thenAnswer((_) => currentUser!.id);
    when(() => userService.getAppUserById(any())).thenAnswer(
      (invocation) async => AppUser(
        profile: Profile(
          id: invocation.positionalArguments.first as String,
          pseudo: 'pseudo',
          avatarUrl: 'path-${invocation.positionalArguments.first}',
        ),
        user: fakeCurrentAppUser.user,
      ),
    );
    final avatarService = MockAvatarService();
    when(() => avatarService.getAvatarUrl(any()))
        .thenAnswer((i) => 'url-${i.positionalArguments.first}');

    container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(client),
        userServiceProvider.overrideWithValue(userService),
        avatarServiceProvider.overrideWithValue(avatarService),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(authEvents.close);
  });

  test('a replayed signedIn for the same user does not reload', () async {
    signIn('user-1');
    container.listen(currentUserAvatarProvider, (_, __) {});
    await _pump();

    verify(() => userService.getAppUserById('user-1')).called(1);
  });

  test('switching to another user reloads exactly once', () async {
    signIn('user-1');
    container.listen(currentUserAvatarProvider, (_, __) {});
    await _pump();

    signIn('user-2');
    await _pump();

    verify(() => userService.getAppUserById('user-1')).called(1);
    verify(() => userService.getAppUserById('user-2')).called(1);
    expect(
      container.read(currentUserAvatarProvider),
      const AsyncValue<String?>.data('url-path-user-2'),
    );
  });

  test('signing in after being signed out loads that user once', () async {
    container.listen(currentUserAvatarProvider, (_, __) {});
    await _pump();
    expect(
      container.read(currentUserAvatarProvider),
      const AsyncValue<String?>.data(null),
    );
    verifyNever(() => userService.getAppUserById(any()));

    signIn('user-1');
    await _pump();

    verify(() => userService.getAppUserById('user-1')).called(1);
    expect(
      container.read(currentUserAvatarProvider),
      const AsyncValue<String?>.data('url-path-user-1'),
    );
  });

  test('an error replayed by the auth stream is swallowed', () async {
    signIn('user-1');
    authEvents.addError(Exception('offline'));
    container.listen(currentUserAvatarProvider, (_, __) {});
    await _pump();

    expect(
      container.read(currentUserAvatarProvider),
      const AsyncValue<String?>.data('url-path-user-1'),
    );
  });

  test('signing out gives no avatar and no error', () async {
    signIn('user-1');
    container.listen(currentUserAvatarProvider, (_, __) {});
    await _pump();

    expect(
      container.read(currentUserAvatarProvider),
      const AsyncValue<String?>.data('url-path-user-1'),
    );

    clearInteractions(userService);
    currentUser = null;
    authEvents.add(const AuthState(AuthChangeEvent.signedOut, null));
    await _pump();

    expect(
      container.read(currentUserAvatarProvider),
      const AsyncValue<String?>.data(null),
    );
    verifyNever(() => userService.getAppUserById(any()));
  });
}
