import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/wish/supabase_wish_stream_repository.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_repository.dart';
import 'package:wishlist/shared/models/wish/wish.dart';

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
