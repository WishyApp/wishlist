import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/friendship/friendship_repository.dart';
import 'package:wishlist/shared/infra/user_service.dart';

import 'fake_data.dart';

// =============================================================================
// MOCK CLASSES
// =============================================================================

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

// ignore: avoid_implementing_value_types
class MockUser extends Mock implements User {}

// ignore: avoid_implementing_value_types
class MockSession extends Mock implements Session {}

/// Session of [user], with the `pseudo` metadata the router redirect expects.
MockSession createMockSession(User user) {
  final session = MockSession();
  when(() => session.user).thenReturn(user);
  when(() => user.userMetadata).thenReturn({'pseudo': 'test'});
  return session;
}

class MockUserService extends Mock implements UserService {}

class MockFriendshipRepository extends Mock implements FriendshipRepository {}

class MockRealtimeChannel extends Mock implements RealtimeChannel {}

class MockRealtimeClient extends Mock implements RealtimeClient {}

// =============================================================================
// MOCK SUPABASE
// =============================================================================

/// Crée un MockSupabaseClient configuré avec un utilisateur de test
///
/// [signedOut] simule l'absence d'utilisateur (`currentUser` null), comme juste
/// après une déconnexion. [userEmail] vaut `test@example.com` par défaut.
MockSupabaseClient createMockSupabaseClient({
  String? userId,
  String? userEmail,
  bool signedOut = false,
}) {
  final mockSupabaseClient = MockSupabaseClient();
  final mockAuth = MockGoTrueClient();
  final mockUser = MockUser();

  final effectiveUserId = userId ?? fakeCurrentUserId;

  when(() => mockSupabaseClient.auth).thenReturn(mockAuth);
  when(() => mockAuth.currentUser).thenReturn(signedOut ? null : mockUser);
  final mockSession = createMockSession(mockUser);
  when(() => mockAuth.currentSession)
      .thenReturn(signedOut ? null : mockSession);
  when(() => mockUser.id).thenReturn(effectiveUserId);
  when(() => mockUser.email).thenReturn(userEmail ?? 'test@example.com');
  when(() => mockAuth.onAuthStateChange)
      .thenAnswer((_) => const Stream.empty());

  // Socket Realtime connecté, lu par les flux pour réabonner un channel.
  final mockRealtime = MockRealtimeClient();
  when(() => mockRealtime.isConnected).thenReturn(true);
  when(() => mockSupabaseClient.realtime).thenReturn(mockRealtime);

  return mockSupabaseClient;
}

// =============================================================================
// FAKE AUTH SESSION
// =============================================================================

/// Faux client Supabase dont l'utilisateur courant peut changer au fil du test.
///
/// `onAuthStateChange` est un BehaviorSubject comme celui de gotrue : un
/// nouvel abonné reçoit le dernier évènement. `currentUser` est mis à jour
/// avant l'évènement, et peut l'être sans évènement via [setUserSilently]
/// (cas où `currentUser` passe à null avant `signedOut`).
class FakeAuthSession {
  FakeAuthSession({String? userId, String? email}) {
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenAnswer((_) => _user);
    when(() => auth.currentSession)
        .thenAnswer((_) => _user == null ? null : createMockSession(_user!));
    when(() => auth.onAuthStateChange).thenAnswer((_) => _events);
    setUserSilently(userId, email: email);
    _events = BehaviorSubject.seeded(
      AuthState(
        userId == null
            ? AuthChangeEvent.initialSession
            : AuthChangeEvent.signedIn,
        null,
      ),
    );
  }

  final MockSupabaseClient client = MockSupabaseClient();
  final MockGoTrueClient auth = MockGoTrueClient();
  late final BehaviorSubject<AuthState> _events;
  User? _user;

  void setUserSilently(String? userId, {String? email}) {
    if (userId == null) {
      _user = null;
      return;
    }
    final user = MockUser();
    when(() => user.id).thenReturn(userId);
    when(() => user.email).thenReturn(email);
    _user = user;
  }

  void signIn(String userId, {String? email}) {
    setUserSilently(userId, email: email);
    _events.add(const AuthState(AuthChangeEvent.signedIn, null));
  }

  void signOut() {
    setUserSilently(null);
    _events.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  /// Évènement sans changement d'utilisateur (ex. renouvellement du token).
  void refreshToken() {
    _events.add(const AuthState(AuthChangeEvent.tokenRefreshed, null));
  }

  /// Exception poussée dans le stream, comme gotrue (notifyException).
  void addAuthError(Object error) => _events.addError(error);

  Future<void> close() => _events.close();
}

// =============================================================================
// MOCK USER SERVICE
// =============================================================================

/// Crée un MockUserService configuré avec des données de test
MockUserService createMockUserService({
  String? userId,
}) {
  final mockUserService = MockUserService();

  when(mockUserService.getCurrentUserId)
      .thenReturn(userId ?? fakeCurrentUserId);

  return mockUserService;
}

// =============================================================================
// FAKE PACKAGE INFO
// =============================================================================

final fakePackageInfo = PackageInfo(
  appName: 'Wishlist',
  packageName: 'com.example.wishlist',
  version: '1.0.0',
  buildNumber: '1',
);
