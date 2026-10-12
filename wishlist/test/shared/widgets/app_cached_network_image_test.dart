import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/shared/widgets/app_cached_network_image.dart';

class _MockCacheManager extends Mock
    implements CacheManager, ImageCacheManager {}

Future<CachedNetworkImage> _pump(
  WidgetTester tester, {
  double? width,
  double? height,
}) async {
  final cacheManager = _MockCacheManager();
  when(
    () => cacheManager.getImageFile(
      any(),
      key: any(named: 'key'),
      headers: any(named: 'headers'),
      withProgress: any(named: 'withProgress'),
      maxHeight: any(named: 'maxHeight'),
      maxWidth: any(named: 'maxWidth'),
    ),
  ).thenAnswer((_) => const Stream<FileResponse>.empty());

  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 3),
      child: InheritedCacheManager(
        cacheManagerOverride: cacheManager,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppCachedNetworkImage.loaded(
            src: 'https://example.com/image.png',
            width: width,
            height: height,
            fit: BoxFit.cover,
          ),
        ),
      ),
    ),
  );

  return tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
}

void main() {
  group('AppCachedNetworkImage memCache', () {
    testWidgets('is not set when width and height are given', (tester) async {
      final image = await _pump(tester, width: 64, height: 64);
      expect(image.memCacheWidth, isNull);
      expect(image.memCacheHeight, isNull);
    });

    testWidgets('uses physical pixels for a single dimension', (tester) async {
      final image = await _pump(tester, width: 64);
      expect(image.memCacheWidth, 192);
      expect(image.memCacheHeight, isNull);
    });
  });

  group('computeMemCacheSize', () {
    test('converts the only known dimension to physical pixels', () {
      expect(
        computeMemCacheSize(width: 40, height: null, devicePixelRatio: 2),
        (width: 80, height: null),
      );
      expect(
        computeMemCacheSize(width: null, height: 40.2, devicePixelRatio: 2),
        (width: null, height: 81),
      );
    });

    test('ignores absent, infinite and non-positive dimensions', () {
      expect(
        computeMemCacheSize(width: null, height: null, devicePixelRatio: 2),
        (width: null, height: null),
      );
      expect(
        computeMemCacheSize(
          width: double.infinity,
          height: 30,
          devicePixelRatio: 2,
        ),
        (width: null, height: 60),
      );
      expect(
        computeMemCacheSize(width: 0, height: double.nan, devicePixelRatio: 2),
        (width: null, height: null),
      );
    });
  });
}
