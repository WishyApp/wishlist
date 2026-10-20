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

class MockUserService extends Mock implements UserService {}

class MockFriendshipRepository extends Mock implements FriendshipRepository {}

class MockRealtimeChannel extends Mock implements RealtimeChannel {}

// =============================================================================
// MOCK SUPABASE
// =============================================================================

/// Crée un MockSupabaseClient configuré avec un utilisateur de test
MockSupabaseClient createMockSupabaseClient({
  String? userId,
}) {
  final mockSupabaseClient = MockSupabaseClient();
  final mockAuth = MockGoTrueClient();
  final mockUser = MockUser();

  final effectiveUserId = userId ?? fakeCurrentUserId;

  when(() => mockSupabaseClient.auth).thenReturn(mockAuth);
  when(() => mockAuth.currentUser).thenReturn(mockUser);
  when(() => mockUser.id).thenReturn(effectiveUserId);
  when(() => mockAuth.onAuthStateChange)
      .thenAnswer((_) => const Stream.empty());

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
  FakeAuthSession({String? userId}) {
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenAnswer((_) => _user);
    when(() => auth.onAuthStateChange).thenAnswer((_) => _events);
    setUserSilently(userId);
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

  void setUserSilently(String? userId) {
    if (userId == null) {
      _user = null;
      return;
    }
    final user = MockUser();
    when(() => user.id).thenReturn(userId);
    _user = user;
  }

  void signIn(String userId) {
    setUserSilently(userId);
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
  String? userEmail,
}) {
  final mockUserService = MockUserService();

  when(mockUserService.getCurrentUserId)
      .thenReturn(userId ?? fakeCurrentUserId);
  when(mockUserService.getCurrentUserEmail)
      .thenReturn(userEmail ?? 'test@example.com');

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
