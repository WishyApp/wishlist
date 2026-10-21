import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/repositories/wish/supabase_wish_stream_repository.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_repository.dart';
import 'package:wishlist/shared/models/booked_wish_with_details/booked_wish_with_details.dart';
import 'package:wishlist/shared/models/wish/wish.dart';

import '../../../../fixtures/fake_data.dart';
import '../../../../fixtures/mock_supabase.dart';

// ignore: avoid_implementing_value_types
class MockPostgresChangePayload extends Mock implements PostgresChangePayload {}

class MockWishRepository extends Mock implements WishRepository {}

typedef _PayloadCallback = void Function(PostgresChangePayload);

class _Listener {
  _Listener({
    required this.event,
    required this.table,
    required this.filter,
    required this.callback,
  });

  final PostgresChangeEvent event;
  final String table;
  final PostgresChangeFilter? filter;
  final _PayloadCallback callback;
}

void main() {
  setUpAll(() => registerFallbackValue(PostgresChangeEvent.all));

  late List<_Listener> listeners;
  late MockSupabaseClient client;
  late MockRealtimeChannel channel;
  late MockWishRepository wishRepository;
  late SupabaseWishStreamRepository repository;

  setUp(() {
    client = createMockSupabaseClient();
    channel = MockRealtimeChannel();
    wishRepository = MockWishRepository();

    listeners = [];
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
      listeners.add(
        _Listener(
          event: invocation.namedArguments[#event] as PostgresChangeEvent,
          table: invocation.namedArguments[#table] as String,
          filter: invocation.namedArguments[#filter] as PostgresChangeFilter?,
          callback: invocation.namedArguments[#callback] as _PayloadCallback,
        ),
      );
      return channel;
    });
    when(channel.subscribe).thenReturn(channel);
    when(channel.unsubscribe).thenAnswer((_) async => 'ok');
    when(() => wishRepository.getWishsFromWishlist(any()))
        .thenAnswer((_) async => const IList<Wish>.empty());

    repository = SupabaseWishStreamRepository(client, wishRepository);
  });

  tearDown(() => repository.dispose());

  /// Simule un changement realtime : recharge le flux.
  void triggerReload() => listeners.first.callback(MockPostgresChangePayload());

  /// Tests communs aux trois flux : [stubLoads] fait retourner les [Completer]
  /// dans l'ordre aux chargements successifs, [stubFailure] fait échouer les
  /// suivants et [stubValue] fait retourner la valeur à tous.
  void streamTests<T>(
    String name, {
    required Stream<T> Function() watch,
    required String channelName,
    required T value,
    required T newest,
    required void Function(T value) stubValue,
    required void Function(List<Completer<T>> loads) stubLoads,
    required void Function() stubFailure,
    required void Function(int times) verifyLoads,
  }) {
    group(name, () {
      test('a second subscriber gets the current value', () async {
        stubValue(value);

        final first = <T>[];
        final firstSub = watch().listen(first.add);
        await pumpEventQueue();
        expect(first, [value]);

        final second = <T>[];
        final secondSub = watch().listen(second.add);
        await pumpEventQueue();

        expect(second, [value]);
        // One load and one channel, shared by both subscribers.
        verifyLoads(1);
        verify(() => client.channel(channelName)).called(1);

        await firstSub.cancel();
        await secondSub.cancel();
      });

      test('an error before any value triggers a reload without being replayed',
          () async {
        final loads = [Completer<T>(), Completer<T>()];
        stubLoads(loads);

        final firstSub = watch().listen((_) {}, onError: (_) {});
        loads[0].completeError(Exception('boom'));
        await pumpEventQueue();

        final errors = <Object>[];
        final values = <T>[];
        final secondSub = watch().listen(values.add, onError: errors.add);
        await pumpEventQueue();
        // The stale cached error is the one being retried: not replayed.
        expect(errors, isEmpty);
        // The new subscriber started a retry.
        verifyLoads(2);

        loads[1].complete(value);
        await pumpEventQueue();
        expect(errors, isEmpty);
        expect(values, [value]);

        await firstSub.cancel();
        await secondSub.cancel();
      });

      test('a retry that fails again emits the new error to the new subscriber',
          () async {
        final loads = [Completer<T>(), Completer<T>()];
        stubLoads(loads);

        final firstSub = watch().listen((_) {}, onError: (_) {});
        loads[0].completeError(Exception('first'));
        await pumpEventQueue();

        final errors = <Object>[];
        final secondSub = watch().listen((_) {}, onError: errors.add);
        await pumpEventQueue();
        expect(errors, isEmpty);

        loads[1].completeError(Exception('second'));
        await pumpEventQueue();
        expect(errors, hasLength(1));
        expect(errors.single.toString(), contains('second'));

        await firstSub.cancel();
        await secondSub.cancel();
      });

      test(
          'an error after a value keeps the value for live and late '
          'subscribers', () async {
        stubValue(value);

        final live = <T>[];
        final liveErrors = <Object>[];
        final firstSub = watch().listen(live.add, onError: liveErrors.add);
        await pumpEventQueue();

        stubFailure();
        triggerReload();
        await pumpEventQueue();

        final late = <T>[];
        final lateErrors = <Object>[];
        final secondSub = watch().listen(late.add, onError: lateErrors.add);
        await pumpEventQueue();

        expect(liveErrors, isEmpty);
        expect(lateErrors, isEmpty);
        expect(live, [value]);
        expect(late, [value]);

        await firstSub.cancel();
        await secondSub.cancel();
      });

      test('out-of-order reloads: the newest wins', () async {
        final older = Completer<T>();
        final newer = Completer<T>();
        stubLoads([older, newer]);

        final live = <T>[];
        final firstSub = watch().listen(live.add);
        triggerReload();

        newer.complete(newest);
        await pumpEventQueue();
        older.complete(value);
        await pumpEventQueue();

        final late = <T>[];
        final secondSub = watch().listen(late.add);
        await pumpEventQueue();

        expect(live, [newest]);
        expect(late, [newest]);

        await firstSub.cancel();
        await secondSub.cancel();
      });

      test(
          'a transient error, then an older slower load: the value is '
          'emitted', () async {
        final older = Completer<T>();
        final failing = Completer<T>();
        stubLoads([older, failing]);

        final live = <T>[];
        final liveErrors = <Object>[];
        final firstSub = watch().listen(live.add, onError: liveErrors.add);
        triggerReload();

        failing.completeError(Exception('transient'));
        await pumpEventQueue();
        expect(liveErrors, hasLength(1));

        older.complete(value);
        await pumpEventQueue();

        final late = <T>[];
        final secondSub = watch().listen(late.add);
        await pumpEventQueue();

        expect(live, [value]);
        expect(late, [value]);

        await firstSub.cancel();
        await secondSub.cancel();
      });

      test('keeps the channel until the last subscriber leaves', () async {
        stubValue(value);

        final firstSub = watch().listen((_) {});
        final secondSub = watch().listen((_) {});
        await pumpEventQueue();

        await firstSub.cancel();
        verifyNever(channel.unsubscribe);

        await secondSub.cancel();
        verify(channel.unsubscribe).called(1);
      });
    });
  }

  streamTests<IList<Wish>>(
    'watchWishsFromWishlist',
    watch: () => repository.watchWishsFromWishlist(7),
    channelName: 'wishs_wishlist_7',
    value: IList([fakeWish1]),
    newest: IList([fakeWish1, fakeWish2]),
    stubValue: (value) => when(() => wishRepository.getWishsFromWishlist(any()))
        .thenAnswer((_) async => value),
    stubLoads: (loads) {
      var call = 0;
      when(() => wishRepository.getWishsFromWishlist(any()))
          .thenAnswer((_) => loads[call++].future);
    },
    stubFailure: () => when(() => wishRepository.getWishsFromWishlist(any()))
        .thenAnswer((_) async => throw Exception('boom')),
    verifyLoads: (times) =>
        verify(() => wishRepository.getWishsFromWishlist(7)).called(times),
  );

  streamTests<Wish>(
    'watchWishById',
    watch: () => repository.watchWishById(3),
    channelName: 'wish_3',
    value: fakeWish1,
    newest: fakeWish2,
    stubValue: (value) => when(() => wishRepository.getWishById(any()))
        .thenAnswer((_) async => value),
    stubLoads: (loads) {
      var call = 0;
      when(() => wishRepository.getWishById(any()))
          .thenAnswer((_) => loads[call++].future);
    },
    stubFailure: () => when(() => wishRepository.getWishById(any()))
        .thenAnswer((_) async => throw Exception('boom')),
    verifyLoads: (times) =>
        verify(() => wishRepository.getWishById(3)).called(times),
  );

  group('watchWishById not found', () {
    test('a wish deleted after a value errors for live and late subscribers',
        () async {
      when(() => wishRepository.getWishById(any()))
          .thenAnswer((_) async => fakeWish1);

      final live = <Wish>[];
      final liveErrors = <Object>[];
      final firstSub =
          repository.watchWishById(3).listen(live.add, onError: liveErrors.add);
      await pumpEventQueue();

      when(() => wishRepository.getWishById(any())).thenAnswer(
        (_) async => throw AppException(
          statusCode: 404,
          cause: const PostgrestException(message: 'none', code: 'PGRST116'),
        ),
      );
      listeners.first.callback(MockPostgresChangePayload());
      await pumpEventQueue();

      final lateErrors = <Object>[];
      final secondSub =
          repository.watchWishById(3).listen((_) {}, onError: lateErrors.add);
      await pumpEventQueue();

      expect(live, [fakeWish1]);
      expect(liveErrors, hasLength(1));
      expect(lateErrors, hasLength(1));

      await firstSub.cancel();
      await secondSub.cancel();
    });
  });

  group('watchWishById not found ordering', () {
    test('not found, then an older reload finishing later: the error stays',
        () async {
      final initial = Completer<Wish>();
      final older = Completer<Wish>();
      final notFound = Completer<Wish>();
      final loads = [initial, older, notFound];
      var call = 0;
      when(() => wishRepository.getWishById(any()))
          .thenAnswer((_) => loads[call++].future);

      final live = <Wish>[];
      final liveErrors = <Object>[];
      final firstSub =
          repository.watchWishById(3).listen(live.add, onError: liveErrors.add);
      initial.complete(fakeWish1);
      await pumpEventQueue();

      // A slow reload starts, then the wish is deleted and fails fast.
      listeners.first.callback(MockPostgresChangePayload());
      listeners.first.callback(MockPostgresChangePayload());
      notFound.completeError(
        AppException(
          statusCode: 404,
          cause: const PostgrestException(message: 'none', code: 'PGRST116'),
        ),
      );
      await pumpEventQueue();
      expect(liveErrors, hasLength(1));

      // The older reload finishes with the wish as it was before deletion.
      older.complete(fakeWish1);
      await pumpEventQueue();

      final late = <Wish>[];
      final lateErrors = <Object>[];
      final secondSub =
          repository.watchWishById(3).listen(late.add, onError: lateErrors.add);
      await pumpEventQueue();

      expect(live, [fakeWish1]);
      expect(liveErrors, hasLength(1));
      expect(late, isEmpty);
      expect(lateErrors, hasLength(1));

      await firstSub.cancel();
      await secondSub.cancel();
    });
  });

  streamTests<IList<BookedWishWithDetails>>(
    'watchBookedWishesByUser',
    watch: () => repository.watchBookedWishesByUser('me'),
    channelName: 'booked_wishes_me',
    value: IList([fakeBookedWish1]),
    newest: fakeBookedWishes,
    stubValue: (value) =>
        when(() => wishRepository.getBookedWishesByUser(any()))
            .thenAnswer((_) async => value),
    stubLoads: (loads) {
      var call = 0;
      when(() => wishRepository.getBookedWishesByUser(any()))
          .thenAnswer((_) => loads[call++].future);
    },
    stubFailure: () => when(() => wishRepository.getBookedWishesByUser(any()))
        .thenAnswer((_) async => throw Exception('boom')),
    verifyLoads: (times) =>
        verify(() => wishRepository.getBookedWishesByUser('me')).called(times),
  );

  group('watchWishsFromWishlist wishlists listener', () {
    PostgresChangePayload payload({
      required Map<String, dynamic> oldRecord,
      required Map<String, dynamic> newRecord,
    }) {
      final p = MockPostgresChangePayload();
      when(() => p.oldRecord).thenReturn(oldRecord);
      when(() => p.newRecord).thenReturn(newRecord);
      return p;
    }

    _Listener wishlistsListener() =>
        listeners.singleWhere((l) => l.table == 'wishlists');

    test('listens to UPDATEs of this wishlist only', () async {
      final sub = repository.watchWishsFromWishlist(7).listen((_) {});

      final l = wishlistsListener();
      expect(l.event, PostgresChangeEvent.update);
      expect(l.filter!.type, PostgresChangeFilterType.eq);
      expect(l.filter!.column, 'id');
      expect(l.filter!.value, 7);
      await sub.cancel();
    });

    test('reloads the wishes when can_owner_see_taken_wish changes', () async {
      final received = <IList<Wish>>[];
      final sub = repository.watchWishsFromWishlist(7).listen(received.add);
      await pumpEventQueue();
      expect(received, hasLength(1));

      wishlistsListener().callback(
        payload(
          oldRecord: {'id': 7, 'can_owner_see_taken_wish': false},
          newRecord: {'id': 7, 'can_owner_see_taken_wish': true},
        ),
      );
      await pumpEventQueue();

      expect(received, hasLength(2));
      verify(() => wishRepository.getWishsFromWishlist(7)).called(2);
      await sub.cancel();
    });

    test('does not reload when another column changes', () async {
      final received = <IList<Wish>>[];
      final sub = repository.watchWishsFromWishlist(7).listen(received.add);
      await pumpEventQueue();

      wishlistsListener().callback(
        payload(
          oldRecord: {'id': 7, 'name': 'a', 'can_owner_see_taken_wish': true},
          newRecord: {'id': 7, 'name': 'b', 'can_owner_see_taken_wish': true},
        ),
      );
      await pumpEventQueue();

      expect(received, hasLength(1));
      await sub.cancel();
    });

    test('reloads when the old value is not provided', () async {
      final received = <IList<Wish>>[];
      final sub = repository.watchWishsFromWishlist(7).listen(received.add);
      await pumpEventQueue();

      wishlistsListener().callback(
        payload(
          oldRecord: {'id': 7},
          newRecord: {'id': 7, 'can_owner_see_taken_wish': true},
        ),
      );
      await pumpEventQueue();

      expect(received, hasLength(2));
      await sub.cancel();
    });
  });
}
