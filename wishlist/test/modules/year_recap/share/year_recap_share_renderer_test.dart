import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/arb/app_localizations.dart';
import 'package:wishlist/modules/year_recap/share/year_recap_share_renderer.dart';
import 'package:wishlist/shared/models/year_recap/year_recap.dart';

import '../../../fixtures/fake_year_recap.dart';

/// An image that fails to load, and keeps its stream to look at the listeners.
class _FailingImage extends ImageProvider<_FailingImage> {
  final completer = _FailingCompleter();

  @override
  Future<_FailingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _FailingImage key,
    ImageDecoderCallback decode,
  ) {
    // Once the renderer is listening
    Future<void>.delayed(
      Duration.zero,
      () => completer.reportError(
        exception: Exception('no network'),
        silent: true,
      ),
    );
    return completer;
  }
}

class _FailingCompleter extends ImageStreamCompleter {
  final listeners = <ImageStreamListener>{};
  final added = <ImageStreamListener>[];

  @override
  void addListener(ImageStreamListener listener) {
    listeners.add(listener);
    added.add(listener);
    super.addListener(listener);
  }

  @override
  void removeListener(ImageStreamListener listener) {
    listeners.remove(listener);
    super.removeListener(listener);
  }
}

void main() {
  final recap = fakeYearRecap(
    stats: YearRecapStats(longestAwaited: fakeLongestAwaited()),
    profile: YearRecapProfileKey.patient,
    illustrationPath: 'patient.png',
  );

  Future<void> expectPng(
    WidgetTester tester, {
    required ImageProvider Function(String url) illustrationProvider,
  }) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('fr'));
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );

    await tester.runAsync(() async {
      final png = await renderYearRecapShareImage(
        context: context,
        recap: recap,
        l10n: l10n,
        illustrationUrl: 'https://example.com/patient.png',
        illustrationProvider: illustrationProvider,
      );
      final codec = await ui.instantiateImageCodec(png);
      final frame = (await codec.getNextFrame()).image;
      expect(frame.width, 1080);
      expect(frame.height, 1920);
      frame.dispose();
    });
  }

  testWidgets('falls back to the bundled illustration when it cannot be loaded',
      (tester) async {
    final failing = _FailingImage();

    await expectPng(tester, illustrationProvider: (_) => failing);

    // The renderer, the last to listen, let go of the failed stream
    // (the image cache keeps its own, which is not ours to remove)
    expect(
      failing.completer.listeners,
      isNot(contains(failing.completer.added.last)),
    );
  });

  testWidgets('renders with the illustration when it loads', (tester) async {
    final bytes = (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 4, 4),
        ui.Paint()..color = Colors.orange,
      );
      final image = await recorder.endRecording().toImage(4, 4);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    }))!;

    await expectPng(
      tester,
      illustrationProvider: (_) => MemoryImage(bytes),
    );
  });
}
