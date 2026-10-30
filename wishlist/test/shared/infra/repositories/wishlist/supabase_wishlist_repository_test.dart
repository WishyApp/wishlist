import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/supabase_wishlist_repository.dart';

import '../../../../fixtures/mock_supabase.dart';

/// An rpc call that returns [_rows].
class FakeRpcRows extends Fake
    implements PostgrestFilterBuilder<List<dynamic>> {
  FakeRpcRows(this._rows);
  final List<dynamic> _rows;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(List<dynamic> value) onValue, {
    Function? onError,
  }) =>
      Future<List<dynamic>>.value(_rows).then(onValue, onError: onError);
}

void main() {
  late MockSupabaseClient client;
  late SupabaseWishlistRepository repository;

  setUp(() {
    client = MockSupabaseClient();
    repository = SupabaseWishlistRepository(client);
  });

  group('getLastActivityByWishlist', () {
    test('calls the rpc and indexes the dates by wishlist id', () async {
      when(
        () => client.rpc<List<dynamic>>('get_my_wishlists_last_activity'),
      ).thenAnswer(
        (_) => FakeRpcRows([
          {'wishlist_id': 3, 'last_activity_at': '2026-03-01T10:00:00+00:00'},
          {'wishlist_id': 7, 'last_activity_at': '2026-05-01T08:30:00+00:00'},
        ]),
      );

      final activity = await repository.getLastActivityByWishlist();

      expect(activity, {
        3: DateTime.utc(2026, 3, 1, 10),
        7: DateTime.utc(2026, 5, 1, 8, 30),
      });
    });

    test('returns an empty map without wishlists', () async {
      when(
        () => client.rpc<List<dynamic>>('get_my_wishlists_last_activity'),
      ).thenAnswer((_) => FakeRpcRows(const []));

      expect(await repository.getLastActivityByWishlist(), isEmpty);
    });
  });
}
