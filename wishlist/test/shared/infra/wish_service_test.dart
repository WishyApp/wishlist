import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_repository.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_repository_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/infra/wish_service.dart';

import '../../fixtures/mock_supabase.dart';

class MockWishRepository extends Mock implements WishRepository {}

class MockImageCompressor extends Mock
    implements FlutterImageCompressPlatform {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(CompressFormat.webp);
  });

  group('WishService.uploadWishImage', () {
    late MockWishRepository repository;
    late ProviderContainer container;
    late WishService service;

    setUp(() {
      repository = MockWishRepository();
      final userService = MockUserService();
      when(userService.getCurrentUserId).thenReturn('user-1');

      container = ProviderContainer(
        overrides: [
          userServiceProvider.overrideWithValue(userService),
          wishRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      service = container.read(wishServiceProvider);

      // flutter_image_compress talks to the platform: answer with fixed bytes.
      final compressor = MockImageCompressor();
      when(
        () => compressor.compressWithFile(
          any(),
          minWidth: any(named: 'minWidth'),
          minHeight: any(named: 'minHeight'),
          quality: any(named: 'quality'),
          format: any(named: 'format'),
        ),
      ).thenAnswer((invocation) async {
        // Different bytes for the main image (1024) and the thumbnail (256).
        final isThumbnail = invocation.namedArguments[#minWidth] == 256;
        return Uint8List.fromList(isThumbnail ? [2] : [1]);
      });
      final previousCompressor = FlutterImageCompressPlatform.instance;
      FlutterImageCompressPlatform.instance = compressor;
      addTearDown(() {
        FlutterImageCompressPlatform.instance = previousCompressor;
      });

      when(
        () => repository.uploadWishImage(
          userId: any(named: 'userId'),
          wishId: any(named: 'wishId'),
          imageData: any(named: 'imageData'),
          fileName: any(named: 'fileName'),
        ),
      ).thenAnswer(
        (invocation) async =>
            'user-1/42/${invocation.namedArguments[#fileName]}',
      );
    });

    test(
      'uploads the main image and the thumbnail for the current user',
      () async {
        final file = File('${Directory.systemTemp.path}/wish_service_test.jpg');

        final path = await service.uploadWishImage(file, 42);

        final captured = verify(
          () => repository.uploadWishImage(
            userId: captureAny(named: 'userId'),
            wishId: captureAny(named: 'wishId'),
            imageData: captureAny(named: 'imageData'),
            fileName: captureAny(named: 'fileName'),
          ),
        ).captured;

        // Two calls, each capturing (userId, wishId, imageData, fileName).
        expect(captured, hasLength(8));
        expect(captured[0], 'user-1');
        expect(captured[1], 42);
        expect(captured[2], Uint8List.fromList([1]));
        expect(captured[3], matches(RegExp(r'^wish_image_\d+\.webp$')));
        expect(captured[4], 'user-1');
        expect(captured[5], 42);
        expect(captured[6], Uint8List.fromList([2]));
        expect(captured[7], matches(RegExp(r'^wish_image_\d+_thumb\.webp$')));
        expect(
          (captured[7] as String).replaceFirst('_thumb', ''),
          captured[3],
        );
        expect(path, 'user-1/42/${captured[3]}');
      },
    );
  });

  group('WishService.deleteWish', () {
    late MockWishRepository repository;
    late WishService service;

    setUp(() {
      repository = MockWishRepository();
      final container = ProviderContainer(
        overrides: [wishRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      service = container.read(wishServiceProvider);
      when(() => repository.deleteWish(any())).thenAnswer((_) async {});
    });

    test('still deletes the wish when removing the main image fails', () async {
      when(() => repository.deleteWishImage(any()))
          .thenThrow(Exception('storage 5xx'));

      await service.deleteWish(7, iconUrl: 'user-1/7/wish_image_1.webp');

      verify(() => repository.deleteWishImage('user-1/7/wish_image_1.webp'))
          .called(1);
      verify(() => repository.deleteWish(7)).called(1);
    });

    test('still deletes the wish when removing the thumbnail fails', () async {
      when(() => repository.deleteWishImage(any())).thenAnswer((_) async {});
      when(
        () => repository.deleteWishImage('user-1/7/wish_image_1_thumb.webp'),
      ).thenThrow(Exception('not found'));

      await service.deleteWish(7, iconUrl: 'user-1/7/wish_image_1.webp');

      verify(() => repository.deleteWish(7)).called(1);
    });
  });
}
