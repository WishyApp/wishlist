import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/supabase_user_completed_wish_repository.dart';

void main() {
  /// A client whose fake PostgREST answers a GET with [existing] (the rows of
  /// the lookup) and any write with an empty body, recording the requests.
  ({SupabaseClient client, List<http.Request> requests}) fakeClient({
    List<Map<String, dynamic>> existing = const [],
  }) {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: MockClient((req) async {
        requests.add(req);
        return http.Response(
          req.method == 'GET' ? jsonEncode(existing) : '',
          req.method == 'GET' ? 200 : 204,
          headers: {'content-type': 'application/json'},
          request: req,
        );
      }),
    );
    addTearDown(client.dispose);
    return (client: client, requests: requests);
  }

  group('SupabaseUserCompletedWishRepository.markAsCompleted', () {
    Future<List<http.Request>> markAsCompleted({
      required List<Map<String, dynamic>> existing,
      required DateTime completedAt,
    }) async {
      final fake = fakeClient(existing: existing);
      await SupabaseUserCompletedWishRepository(fake.client).markAsCompleted(
        userId: 'me',
        wishId: 7,
        fromWishlistId: 3,
        quantity: 2,
        completedAt: completedAt,
      );
      return fake.requests;
    }

    test('inserts the day the wish was received', () async {
      final requests = await markAsCompleted(
        existing: [],
        completedAt: DateTime(2026, 3, 5),
      );

      final insert = requests.last;
      expect(insert.method, 'POST');
      expect(jsonDecode(insert.body), {
        'user_id': 'me',
        'wish_id': 7,
        'from_wishlist_id': 3,
        'quantity': 2,
        'completed_at': '2026-03-05',
      });
    });

    test('adds the quantity and keeps a more recent day', () async {
      final requests = await markAsCompleted(
        existing: [
          {'quantity': 1, 'completed_at': '2026-03-01'},
        ],
        completedAt: DateTime(2026, 3, 5),
      );

      final update = requests.last;
      expect(update.method, 'PATCH');
      expect(
        jsonDecode(update.body),
        {'quantity': 3, 'completed_at': '2026-03-05'},
      );
    });

    test('keeps the day already saved when it is more recent', () async {
      final requests = await markAsCompleted(
        existing: [
          {'quantity': 1, 'completed_at': '2026-03-10'},
        ],
        completedAt: DateTime(2026, 3, 5),
      );

      expect(
        jsonDecode(requests.last.body),
        {'quantity': 3, 'completed_at': '2026-03-10'},
      );
    });
  });

  group('SupabaseUserCompletedWishRepository.getCompletedWishesByUser', () {
    test('reads the day of completion, the last completed first', () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        httpClient: MockClient((req) async {
          requests.add(req);
          return http.Response(
            jsonEncode([
              {
                'completed_at': '2026-03-05',
                'quantity': 1,
                'wishs': {
                  'id': 7,
                  'created_at': '2026-01-01T10:00:00Z',
                  'name': 'Kindle',
                  'description': '',
                  'quantity': 1,
                  'wishlist_id': 3,
                  'updated_by': 'me',
                  'updated_at': '2026-01-01T10:00:00Z',
                  'taken_by_user': <Map<String, dynamic>>[],
                  'wishlist': {
                    'name': 'Noël',
                    'deleted_at': null,
                    'id_owner': 'me',
                    'profiles': {'pseudo': 'Alice', 'avatar_url': null},
                  },
                },
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: req,
          );
        }),
      );
      addTearDown(client.dispose);

      final result = await SupabaseUserCompletedWishRepository(client)
          .getCompletedWishesByUser('me');

      expect(result.single.completedAt, DateTime(2026, 3, 5));
      expect(
        requests.single.url.queryParameters['order'],
        'completed_at.desc.nullslast,created_at.desc.nullslast',
      );
    });
  });
}
