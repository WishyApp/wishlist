import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/supabase_user_completed_wish_repository.dart';
import 'package:wishlist/shared/models/received_wishes_summary/received_wishes_summary.dart';

void main() {
  /// A client whose fake PostgREST answers a GET with [existing] (the rows of
  /// the lookup), an UPDATE with [updated] (the rows it matched) and an
  /// INSERT with an empty body, recording the requests.
  ({SupabaseClient client, List<http.Request> requests}) fakeClient({
    List<Map<String, dynamic>> existing = const [],
    List<Map<String, dynamic>> updated = const [
      {'wish_id': 7},
    ],
  }) {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: MockClient((req) async {
        requests.add(req);
        return switch (req.method) {
          'GET' => http.Response(
              jsonEncode(existing),
              200,
              headers: {'content-type': 'application/json'},
              request: req,
            ),
          'PATCH' => http.Response(
              jsonEncode(updated),
              200,
              headers: {'content-type': 'application/json'},
              request: req,
            ),
          _ => http.Response('', 201, request: req),
        };
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

  test('SupabaseUserCompletedWishRepository.updateCompletionDate sets the day',
      () async {
    final fake = fakeClient();
    await SupabaseUserCompletedWishRepository(fake.client).updateCompletionDate(
      userId: 'me',
      wishId: 7,
      completedAt: DateTime(2025, 12, 24),
    );

    final update = fake.requests.single;
    expect(update.method, 'PATCH');
    expect(update.url.queryParameters['user_id'], 'eq.me');
    expect(update.url.queryParameters['wish_id'], 'eq.7');
    expect(jsonDecode(update.body), {'completed_at': '2025-12-24'});
  });

  test(
      'SupabaseUserCompletedWishRepository.updateCompletionDate fails on a '
      'completed wish that is gone', () async {
    final fake = fakeClient(updated: []);

    await expectLater(
      SupabaseUserCompletedWishRepository(fake.client).updateCompletionDate(
        userId: 'me',
        wishId: 7,
        completedAt: DateTime(2025, 12, 24),
      ),
      throwsA(isA<AppException>()),
    );
    expect(fake.requests.single.url.queryParameters['select'], 'wish_id');
  });

  test(
      'SupabaseUserCompletedWishRepository.updateCompletedWishQuantity fails '
      'on a completed wish that is gone', () async {
    final fake = fakeClient(updated: []);

    await expectLater(
      SupabaseUserCompletedWishRepository(fake.client)
          .updateCompletedWishQuantity(userId: 'me', wishId: 7, newQuantity: 2),
      throwsA(isA<AppException>()),
    );
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

  group('SupabaseUserCompletedWishRepository.getReceivedWishesSummary', () {
    Future<(ReceivedWishesSummary, List<http.Request>)> summary(
      List<Map<String, dynamic>> rows,
    ) async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        httpClient: MockClient((req) async {
          requests.add(req);
          return http.Response(
            jsonEncode(rows),
            200,
            headers: {'content-type': 'application/json'},
            request: req,
          );
        }),
      );
      addTearDown(client.dispose);

      final result = await SupabaseUserCompletedWishRepository(client)
          .getReceivedWishesSummary('me');
      return (result, requests);
    }

    test('counts the rows of the user and gives the latest day', () async {
      final (result, requests) = await summary([
        {'completed_at': '2026-03-05', 'wishs': <String, dynamic>{}},
        {'completed_at': '2026-03-01', 'wishs': <String, dynamic>{}},
        {'completed_at': '2026-02-10', 'wishs': <String, dynamic>{}},
      ]);

      expect(result.count, 3);
      expect(result.latestCompletedAt, DateTime(2026, 3, 5));
      final query = requests.single.url.queryParameters;
      expect(query['user_id'], 'eq.me');
      expect(query['order'], 'completed_at.desc.nullslast');
      // The same inner joins as the full list, so the same rows are counted
      expect(query['select'], contains('wishs!inner'));
      expect(query['select'], contains('wishlists!inner'));
      expect(query['select'], contains('profiles!inner'));
    });

    test('is empty without any row', () async {
      final (result, _) = await summary([]);

      expect(result, const ReceivedWishesSummary.empty());
      expect(result.latestCompletedAt, isNull);
    });
  });
}
