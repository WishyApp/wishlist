import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/shared/widgets/app_cached_network_image.dart';

class _MockCacheManager extends Mock
    implements CacheManager, ImageCacheManager {}

/// Writes a real 8x4 PNG to a temporary file so that the image is decoded.
Future<File> _writePng(WidgetTester tester) async {
  const fileSystem = LocalFileSystem();
  final file = fileSystem.file(
    '${io.Directory.systemTemp.createTempSync().path}/image.png',
  );
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 8, 4),
      Paint()..color = const Color(0xFF00FF00),
    );
    final image = await recorder.endRecording().toImage(8, 4);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
  return file;
}

Future<CachedNetworkImage> _pump(
  WidgetTester tester, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  File? imageFile,
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
  ).thenAnswer(
    (_) => imageFile == null
        ? const Stream<FileResponse>.empty()
        : Stream<FileResponse>.value(
            FileInfo(
              imageFile,
              FileSource.Cache,
              DateTime.now().add(const Duration(days: 1)),
              'https://example.com/image.png',
            ),
          ),
  );

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
            fit: fit,
          ),
        ),
      ),
    ),
  );

  if (imageFile != null) {
    // Lets the file be read and decoded for real, and the fade-in finish.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

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
      final image = await _pump(tester, width: 64, fit: BoxFit.contain);
      expect(image.memCacheWidth, 192);
      expect(image.memCacheHeight, isNull);
    });
  });

  group('AppCachedNetworkImage memCache fit', () {
    testWidgets('is not set for a single dimension with BoxFit.cover', (
      tester,
    ) async {
      // The other axis follows the parent constraints, not the image ratio:
      // a downscaled decode would be stretched to cover it and look blurry.
      final width = await _pump(tester, width: 64);
      expect(width.memCacheWidth, isNull);
      expect(width.memCacheHeight, isNull);
      final height = await _pump(tester, height: 64);
      expect(height.memCacheWidth, isNull);
      expect(height.memCacheHeight, isNull);
    });

    testWidgets('is set for a single dimension when the fit never overflows', (
      tester,
    ) async {
      for (final fit in [BoxFit.contain, BoxFit.scaleDown, BoxFit.fitWidth]) {
        final image = await _pump(tester, width: 64, fit: fit);
        expect(image.memCacheWidth, 192, reason: '$fit');
      }
      for (final fit in [BoxFit.contain, BoxFit.scaleDown, BoxFit.fitHeight]) {
        final image = await _pump(tester, height: 64, fit: fit);
        expect(image.memCacheHeight, 192, reason: '$fit');
      }
    });

    testWidgets('is not set without any dimension', (tester) async {
      final image = await _pump(tester, fit: BoxFit.contain);
      expect(image.memCacheWidth, isNull);
      expect(image.memCacheHeight, isNull);
    });
  });

  group('AppCachedNetworkImage decoding', () {
    setUp(() => PaintingBinding.instance.imageCache.clear());
    tearDown(() => PaintingBinding.instance.imageCache.clear());

    for (final (name, width, height, fit) in [
      ('width and height', 64.0, 64.0, BoxFit.cover),
      ('width only', 64.0, null, BoxFit.contain),
      ('height only', null, 64.0, BoxFit.contain),
      ('no dimension', null, null, BoxFit.contain),
    ]) {
      testWidgets('decodes the image once with $name', (tester) async {
        final file = await _writePng(tester);
        await _pump(
          tester,
          width: width,
          height: height,
          fit: fit,
          imageFile: file,
        );

        expect(PaintingBinding.instance.imageCache.currentSize, 1);
      });
    }
  });

  group('computeMemCacheSize', () {
    test('converts the only known dimension to physical pixels', () {
      expect(
        computeMemCacheSize(
          width: 40,
          height: null,
          fit: BoxFit.contain,
          devicePixelRatio: 2,
        ),
        (width: 80, height: null),
      );
      expect(
        computeMemCacheSize(
          width: null,
          height: 40.2,
          fit: BoxFit.contain,
          devicePixelRatio: 2,
        ),
        (width: null, height: 81),
      );
    });

    test('ignores absent, infinite and non-positive dimensions', () {
      expect(
        computeMemCacheSize(
          width: null,
          height: null,
          fit: BoxFit.contain,
          devicePixelRatio: 2,
        ),
        (width: null, height: null),
      );
      expect(
        computeMemCacheSize(
          width: double.infinity,
          height: 30,
          fit: BoxFit.contain,
          devicePixelRatio: 2,
        ),
        (width: null, height: 60),
      );
      expect(
        computeMemCacheSize(
          width: 0,
          height: double.nan,
          fit: BoxFit.contain,
          devicePixelRatio: 2,
        ),
        (width: null, height: null),
      );
    });

    test('ignores a fit whose scale depends on the other axis', () {
      for (final fit in [BoxFit.cover, BoxFit.fill, BoxFit.none]) {
        expect(
          computeMemCacheSize(
            width: 40,
            height: null,
            fit: fit,
            devicePixelRatio: 2,
          ),
          (width: null, height: null),
          reason: '$fit',
        );
      }
      expect(
        computeMemCacheSize(
          width: 40,
          height: null,
          fit: BoxFit.fitHeight,
          devicePixelRatio: 2,
        ),
        (width: null, height: null),
      );
      expect(
        computeMemCacheSize(
          width: null,
          height: 40,
          fit: BoxFit.fitWidth,
          devicePixelRatio: 2,
        ),
        (width: null, height: null),
      );
    });

    test('treats a null fit like scaleDown', () {
      expect(
        computeMemCacheSize(
          width: 40,
          height: null,
          fit: null,
          devicePixelRatio: 2,
        ),
        (width: 80, height: null),
      );
    });

    test('returns nothing when width and height are both given', () {
      expect(
        computeMemCacheSize(
          width: 40,
          height: 40,
          fit: BoxFit.contain,
          devicePixelRatio: 2,
        ),
        (width: null, height: null),
      );
    });
  });
}
