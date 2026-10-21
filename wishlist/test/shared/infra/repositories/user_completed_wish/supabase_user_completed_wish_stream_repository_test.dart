import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/supabase_user_completed_wish_stream_repository.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_repository.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';

import '../../../../fixtures/fake_data.dart';
import '../../../../fixtures/mock_supabase.dart';

// ignore: avoid_implementing_value_types
class MockPostgresChangePayload extends Mock implements PostgresChangePayload {}

class MockUserCompletedWishRepository extends Mock
    implements UserCompletedWishRepository {}

typedef _PayloadCallback = void Function(PostgresChangePayload);
typedef _StatusCallback = void Function(RealtimeSubscribeStatus, Object?);
typedef _Wishes = IList<CompletedWishWithDetails>;

final _completedWish = CompletedWishWithDetails(
  wish: fakeWish1,
  fromWishlistId: 1,
  fromWishlistName: 'w',
  ownerPseudo: 'Alice',
  ownerId: fakeFriendUserId1,
  completedAt: fakeCreatedAt,
  quantity: 1,
);

void main() {
  setUpAll(() => registerFallbackValue(PostgresChangeEvent.all));

  late MockSupabaseClient client;
  late MockRealtimeChannel channel;
  late MockUserCompletedWishRepository completedWishRepository;
  late SupabaseUserCompletedWishStreamRepository repository;
  late List<_PayloadCallback> callbacks;

  /// Status callbacks passed to `channel.subscribe`, in order.
  late List<_StatusCallback> statusCallbacks;

  /// Simule un changement realtime : recharge les wishs complétés.
  void triggerReload() => callbacks.first(MockPostgresChangePayload());

  /// Les chargements successifs retournent les [Completer] dans l'ordre.
  void stubLoads(List<Completer<_Wishes>> loads) {
    var call = 0;
    when(() => completedWishRepository.getCompletedWishesByUser(any()))
        .thenAnswer((_) => loads[call++].future);
  }

  setUp(() {
    client = createMockSupabaseClient();
    channel = MockRealtimeChannel();
    completedWishRepository = MockUserCompletedWishRepository();
    callbacks = [];
    statusCallbacks = [];

    when(() => client.channel(any())).thenReturn(channel);
    when(
      () => channel.onPostgresChanges(
        event: any(named: 'event'),
        schema: any(named: 'schema'),
        table: any(named: 'table'),
        filter: any(named: 'filter'),
        callback: any(named: 'callback'),
      ),
    ).thenAnswer((invocation) {
      callbacks.add(
        invocation.namedArguments[#callback] as _PayloadCallback,
      );
      return channel;
    });
    when(() => channel.subscribe(any())).thenAnswer((invocation) {
      final callback = invocation.positionalArguments.first as _StatusCallback?;
      if (callback != null) {
        statusCallbacks.add(callback);
      }
      return channel;
    });
    when(channel.unsubscribe).thenAnswer((_) async => 'ok');
    when(() => completedWishRepository.getCompletedWishesByUser(any()))
        .thenAnswer((_) async => IList([_completedWish]));

    repository = SupabaseUserCompletedWishStreamRepository(
      client,
      completedWishRepository,
    );
  });

  tearDown(() => repository.dispose());

  group('watchCompletedWishesByUser', () {
    test('a second subscriber on the same user gets the current value',
        () async {
      final first = <_Wishes>[];
      final firstSub =
          repository.watchCompletedWishesByUser('me').listen(first.add);
      await pumpEventQueue();
      expect(first, [
        IList([_completedWish]),
      ]);

      final second = <_Wishes>[];
      final secondSub =
          repository.watchCompletedWishesByUser('me').listen(second.add);
      await pumpEventQueue();

      expect(second, [
        IList([_completedWish]),
      ]);
      // One load and one channel, shared by both subscribers.
      verify(() => completedWishRepository.getCompletedWishesByUser('me'))
          .called(1);
      verify(() => client.channel('completed_wishes_me')).called(1);

      await firstSub.cancel();
      await secondSub.cancel();
    });

    test('an error before any value triggers a reload without being replayed',
        () async {
      final loads = [Completer<_Wishes>(), Completer<_Wishes>()];
      stubLoads(loads);

      final firstSub = repository
          .watchCompletedWishesByUser('me')
          .listen((_) {}, onError: (_) {});
      loads[0].completeError(Exception('boom'));
      await pumpEventQueue();

      final errors = <Object>[];
      final values = <_Wishes>[];
      final secondSub = repository
          .watchCompletedWishesByUser('me')
          .listen(values.add, onError: errors.add);
      await pumpEventQueue();
      // The stale cached error is the one being retried: not replayed.
      expect(errors, isEmpty);
      // The new subscriber started a retry.
      verify(() => completedWishRepository.getCompletedWishesByUser('me'))
          .called(2);

      loads[1].complete(IList([_completedWish]));
      await pumpEventQueue();
      expect(errors, isEmpty);
      expect(values, [
        IList([_completedWish]),
      ]);

      await firstSub.cancel();
      await secondSub.cancel();
    });

    test('a retry that fails again emits the new error to the new subscriber',
        () async {
      final loads = [Completer<_Wishes>(), Completer<_Wishes>()];
      stubLoads(loads);

      final firstSub = repository
          .watchCompletedWishesByUser('me')
          .listen((_) {}, onError: (_) {});
      loads[0].completeError(Exception('first'));
      await pumpEventQueue();

      final errors = <Object>[];
      final secondSub = repository
          .watchCompletedWishesByUser('me')
          .listen((_) {}, onError: errors.add);
      await pumpEventQueue();
      expect(errors, isEmpty);

      loads[1].completeError(Exception('second'));
      await pumpEventQueue();
      expect(errors, hasLength(1));
      expect(errors.single.toString(), contains('second'));

      await firstSub.cancel();
      await secondSub.cancel();
    });

    test('reloads when the channel reaches subscribed', () async {
      final loads = [Completer<_Wishes>(), Completer<_Wishes>()];
      stubLoads(loads);

      final received = <_Wishes>[];
      final sub =
          repository.watchCompletedWishesByUser('me').listen(received.add);
      loads[0].complete(IList([_completedWish]));
      await pumpEventQueue();

      // Other statuses do not reload.
      statusCallbacks.single(RealtimeSubscribeStatus.closed, null);
      await pumpEventQueue();
      verify(() => completedWishRepository.getCompletedWishesByUser('me'))
          .called(1);

      statusCallbacks.single(RealtimeSubscribeStatus.subscribed, null);
      final fresh = IList([_completedWish, _completedWish]);
      loads[1].complete(fresh);
      await pumpEventQueue();

      verify(() => completedWishRepository.getCompletedWishesByUser('me'))
          .called(1);
      expect(received, [
        IList([_completedWish]),
        fresh,
      ]);

      await sub.cancel();
    });

    test('an error after a value keeps the value for live and late subscribers',
        () async {
      final live = <_Wishes>[];
      final liveErrors = <Object>[];
      final firstSub = repository
          .watchCompletedWishesByUser('me')
          .listen(live.add, onError: liveErrors.add);
      await pumpEventQueue();

      when(() => completedWishRepository.getCompletedWishesByUser(any()))
          .thenAnswer((_) async => throw Exception('boom'));
      triggerReload();
      await pumpEventQueue();

      final late = <_Wishes>[];
      final lateErrors = <Object>[];
      final secondSub = repository
          .watchCompletedWishesByUser('me')
          .listen(late.add, onError: lateErrors.add);
      await pumpEventQueue();

      expect(liveErrors, isEmpty);
      expect(lateErrors, isEmpty);
      expect(live, hasLength(1));
      expect(late, [
        IList([_completedWish]),
      ]);

      await firstSub.cancel();
      await secondSub.cancel();
    });

    test('out-of-order reloads: the newest wins', () async {
      final older = Completer<_Wishes>();
      final newer = Completer<_Wishes>();
      stubLoads([older, newer]);

      final live = <_Wishes>[];
      final firstSub =
          repository.watchCompletedWishesByUser('me').listen(live.add);
      triggerReload();

      final newest = IList([_completedWish, _completedWish]);
      newer.complete(newest);
      await pumpEventQueue();
      older.complete(IList([_completedWish]));
      await pumpEventQueue();

      final late = <_Wishes>[];
      final secondSub =
          repository.watchCompletedWishesByUser('me').listen(late.add);
      await pumpEventQueue();

      expect(live, [newest]);
      expect(late, [newest]);

      await firstSub.cancel();
      await secondSub.cancel();
    });

    test('keeps the channel until the last subscriber leaves', () async {
      final firstSub =
          repository.watchCompletedWishesByUser('me').listen((_) {});
      final secondSub =
          repository.watchCompletedWishesByUser('me').listen((_) {});
      await pumpEventQueue();

      await firstSub.cancel();
      verifyNever(channel.unsubscribe);

      await secondSub.cancel();
      verify(channel.unsubscribe).called(1);
    });

    test('a new subscriber after full cleanup reloads and gets the value',
        () async {
      final firstSub =
          repository.watchCompletedWishesByUser('me').listen((_) {});
      await pumpEventQueue();
      await firstSub.cancel();

      final received = <_Wishes>[];
      final secondSub =
          repository.watchCompletedWishesByUser('me').listen(received.add);
      await pumpEventQueue();

      expect(received, [
        IList([_completedWish]),
      ]);
      verify(() => completedWishRepository.getCompletedWishesByUser('me'))
          .called(2);

      await secondSub.cancel();
    });
  });
}
