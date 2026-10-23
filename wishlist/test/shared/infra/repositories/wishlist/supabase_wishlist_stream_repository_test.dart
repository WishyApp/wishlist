import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/supabase_wishlist_stream_repository.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_repository.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';

import '../../../../fixtures/fake_data.dart';
import '../../../../fixtures/mock_supabase.dart';

// ignore: avoid_implementing_value_types
class MockPostgresChangePayload extends Mock implements PostgresChangePayload {}

class MockWishlistRepository extends Mock implements WishlistRepository {}

typedef _PayloadCallback = void Function(PostgresChangePayload);
typedef _StatusCallback = void Function(RealtimeSubscribeStatus, Object?);

void main() {
  setUpAll(() => registerFallbackValue(PostgresChangeEvent.all));

  late MockSupabaseClient client;
  late MockRealtimeChannel channel;

  /// Status callbacks passed to `channel.subscribe`, in order.
  late List<_StatusCallback> statusCallbacks;
  late MockWishlistRepository wishlistRepository;
  late SupabaseWishlistStreamRepository repository;
  late List<_PayloadCallback> callbacks;

  /// Simule un changement realtime : recharge le flux.
  void triggerReload({Map<String, dynamic> newRecord = const {}}) {
    final payload = MockPostgresChangePayload();
    when(() => payload.eventType).thenReturn(PostgresChangeEvent.update);
    when(() => payload.newRecord).thenReturn(newRecord);
    callbacks.first(payload);
  }

  setUp(() {
    client = createMockSupabaseClient();
    channel = MockRealtimeChannel();
    statusCallbacks = [];
    wishlistRepository = MockWishlistRepository();
    callbacks = [];

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
      statusCallbacks.add(
        invocation.positionalArguments.first as _StatusCallback,
      );
      return channel;
    });
    when(channel.unsubscribe).thenAnswer((_) async => 'ok');

    repository = SupabaseWishlistStreamRepository(client, wishlistRepository);
  });

  tearDown(() => repository.dispose());

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
      test('reloads each time the channel reports subscribed', () async {
        stubValue(value);

        final sub = watch().listen((_) {});
        await pumpEventQueue();
        verifyLoads(1);

        // Changement manqué avant le premier subscribed, puis après un rejoin.
        expect(statusCallbacks, hasLength(1));
        statusCallbacks.single(RealtimeSubscribeStatus.subscribed, null);
        await pumpEventQueue();
        verifyLoads(1);

        statusCallbacks.single(RealtimeSubscribeStatus.subscribed, null);
        await pumpEventQueue();
        verifyLoads(1);

        await sub.cancel();
      });

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

  final wishlists = IList([fakeWishlist1]);
  final moreWishlists = IList([fakeWishlist1, fakeWishlist2]);

  streamTests<IList<Wishlist>>(
    'watchWishlistsByUser',
    watch: () => repository.watchWishlistsByUser('me'),
    channelName: 'wishlists_user_me',
    value: wishlists,
    newest: moreWishlists,
    stubValue: (value) =>
        when(() => wishlistRepository.getWishlistsByUser(any()))
            .thenAnswer((_) async => value),
    stubLoads: (loads) {
      var call = 0;
      when(() => wishlistRepository.getWishlistsByUser(any()))
          .thenAnswer((_) => loads[call++].future);
    },
    stubFailure: () => when(() => wishlistRepository.getWishlistsByUser(any()))
        .thenAnswer((_) async => throw Exception('boom')),
    verifyLoads: (times) =>
        verify(() => wishlistRepository.getWishlistsByUser('me')).called(times),
  );

  streamTests<IList<Wishlist>>(
    'watchPublicWishlistsByUser',
    watch: () => repository.watchPublicWishlistsByUser('me'),
    channelName: 'wishlists_public_user_me',
    value: wishlists,
    newest: moreWishlists,
    stubValue: (value) =>
        when(() => wishlistRepository.getPublicWishlistsByUser(any()))
            .thenAnswer((_) async => value),
    stubLoads: (loads) {
      var call = 0;
      when(() => wishlistRepository.getPublicWishlistsByUser(any()))
          .thenAnswer((_) => loads[call++].future);
    },
    stubFailure: () =>
        when(() => wishlistRepository.getPublicWishlistsByUser(any()))
            .thenAnswer((_) async => throw Exception('boom')),
    verifyLoads: (times) =>
        verify(() => wishlistRepository.getPublicWishlistsByUser('me'))
            .called(times),
  );

  streamTests<Wishlist?>(
    'watchWishlistById',
    watch: () => repository.watchWishlistById(1),
    channelName: 'wishlist_1',
    value: fakeWishlist1,
    newest: fakeWishlist2,
    stubValue: (value) => when(() => wishlistRepository.findWishlistById(any()))
        .thenAnswer((_) async => value),
    stubLoads: (loads) {
      var call = 0;
      when(() => wishlistRepository.findWishlistById(any()))
          .thenAnswer((_) => loads[call++].future);
    },
    stubFailure: () => when(() => wishlistRepository.findWishlistById(any()))
        .thenAnswer((_) async => throw Exception('boom')),
    verifyLoads: (times) =>
        verify(() => wishlistRepository.findWishlistById(1)).called(times),
  );

  group('watchWishlistById archiving', () {
    test('an archived wishlist emits null without reloading', () async {
      when(() => wishlistRepository.findWishlistById(any()))
          .thenAnswer((_) async => fakeWishlist1);

      final received = <Wishlist?>[];
      final sub = repository.watchWishlistById(1).listen(received.add);
      await pumpEventQueue();

      triggerReload(newRecord: {'deleted_at': '2024-01-01T00:00:00Z'});
      await pumpEventQueue();

      expect(received, [fakeWishlist1, null]);
      verify(() => wishlistRepository.findWishlistById(1)).called(1);

      await sub.cancel();
    });

    test('an older fetch finishing after the archive keeps it null', () async {
      final older = Completer<Wishlist?>();
      when(() => wishlistRepository.findWishlistById(any()))
          .thenAnswer((_) => older.future);

      final live = <Wishlist?>[];
      final firstSub = repository.watchWishlistById(1).listen(live.add);
      triggerReload(newRecord: {'deleted_at': '2024-01-01T00:00:00Z'});
      await pumpEventQueue();
      older.complete(fakeWishlist1);
      await pumpEventQueue();

      final late = <Wishlist?>[];
      final secondSub = repository.watchWishlistById(1).listen(late.add);
      await pumpEventQueue();

      expect(live, [null]);
      expect(late, [null]);

      await firstSub.cancel();
      await secondSub.cancel();
    });
  });
}
