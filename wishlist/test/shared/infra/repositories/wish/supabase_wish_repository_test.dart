import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/wish/supabase_wish_repository.dart';

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
}
