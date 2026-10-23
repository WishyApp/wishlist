import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/wish/supabase_wish_repository.dart';
import 'package:wishlist/shared/models/booked_wish_with_details/booked_wish_with_details.dart';

import '../../../../fixtures/mock_supabase.dart';

class MockSupabaseStorageClient extends Mock implements SupabaseStorageClient {}

class MockStorageFileApi extends Mock implements StorageFileApi {}

void main() {
  group('wishImageStoragePath', () {
    test('prefixes the path with the user id', () {
      expect(
        wishImageStoragePath(
          userId: 'user-1',
          wishId: 42,
          fileName: 'wish_image_1.webp',
        ),
        'user-1/42/wish_image_1.webp',
      );
    });
  });

  group('SupabaseWishRepository.uploadWishImage', () {
    test('uploads under <userId>/<wishId>/<fileName>', () async {
      final client = MockSupabaseClient();
      final storage = MockSupabaseStorageClient();
      final bucket = MockStorageFileApi();
      final data = Uint8List.fromList([1, 2, 3]);

      when(() => client.storage).thenReturn(storage);
      when(() => storage.from('wish-images')).thenReturn(bucket);
      when(
        () => bucket.uploadBinary('user-1/42/wish_image_1.webp', data),
      ).thenAnswer((_) async => 'wish-images/ignored');

      final path = await SupabaseWishRepository(client).uploadWishImage(
        userId: 'user-1',
        wishId: 42,
        imageData: data,
        fileName: 'wish_image_1.webp',
      );

      expect(path, 'user-1/42/wish_image_1.webp');
      verify(
        () => bucket.uploadBinary('user-1/42/wish_image_1.webp', data),
      ).called(1);
    });
  });

  group('SupabaseWishRepository.getBookedWishesByUser', () {
    const ownerId = 'owner-1';

    Map<String, dynamic> booking({
      required int quantity,
      required List<Map<String, dynamic>> receipts,
    }) =>
        {
          'quantity': 1,
          'wishs': {
            'id': 7,
            'created_at': '2026-10-01T10:00:00Z',
            'name': 'Kindle',
            'description': '',
            'quantity': quantity,
            'wishlist_id': 3,
            'updated_by': ownerId,
            'updated_at': '2026-10-01T10:00:00Z',
            'taken_by_user': <Map<String, dynamic>>[],
            'user_completed_wishs': receipts,
            'wishlists': {
              'name': 'Noël',
              'id_owner': ownerId,
              'profiles': {'pseudo': 'Alice', 'avatar_url': null},
            },
          },
        };

    /// Runs the query against a fake PostgREST answering [rows]
    Future<({http.Request request, List<BookedWishWithDetails> result})> fetch(
      List<Map<String, dynamic>> rows,
    ) async {
      late http.Request request;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        httpClient: MockClient((req) async {
          request = req;
          return http.Response(
            jsonEncode(rows),
            200,
            headers: {'content-type': 'application/json'},
            request: req,
          );
        }),
      );
      addTearDown(client.dispose);

      final result =
          await SupabaseWishRepository(client).getBookedWishesByUser('me');
      return (request: request, result: result.toList());
    }

    test('embeds the receipts of the booked wishes', () async {
      final (:request, result: _) = await fetch([]);

      expect(
        request.url.queryParameters['select'],
        contains('user_completed_wishs(user_id,quantity,created_at)'),
      );
    });

    test("reads the owner's receipt only", () async {
      final (request: _, :result) = await fetch([
        booking(
          quantity: 1,
          receipts: [
            {
              'user_id': 'someone-else',
              'quantity': 1,
              'created_at': '2026-10-02T08:00:00Z',
            },
            {
              'user_id': ownerId,
              'quantity': 1,
              'created_at': '2026-10-05T08:00:00Z',
            },
          ],
        ),
      ]);

      final bookedWish = result.single;
      expect(bookedWish.receivedQuantity, 1);
      expect(bookedWish.receivedAt, DateTime.utc(2026, 10, 5, 8));
      expect(bookedWish.isGiven, isTrue);
    });

    test('a wish received by someone else only is not given', () async {
      final (request: _, :result) = await fetch([
        booking(
          quantity: 1,
          receipts: [
            {
              'user_id': 'someone-else',
              'quantity': 1,
              'created_at': '2026-10-02T08:00:00Z',
            },
          ],
        ),
      ]);

      final bookedWish = result.single;
      expect(bookedWish.receivedQuantity, 0);
      expect(bookedWish.receivedAt, isNull);
      expect(bookedWish.isGiven, isFalse);
    });
  });
}
