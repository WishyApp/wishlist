import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/l10n/arb/app_localizations.dart';
import 'package:wishlist/modules/year_recap/share/year_recap_share_image.dart';
import 'package:wishlist/shared/models/year_recap/year_recap.dart';

/// How long the illustration of the bucket may take before the generic one
/// replaces it.
const _illustrationTimeout = Duration(seconds: 4);

/// Draws [YearRecapShareImage] off-screen and returns it as a PNG of
/// 1080x1920. The illustration (the one at [illustrationUrl], or the bundled
/// generic one when there is none or it cannot be loaded) and the logo are
/// loaded before anything is drawn, so the capture never misses them.
Future<Uint8List> renderYearRecapShareImage({
  required BuildContext context,
  required YearRecapData recap,
  required AppLocalizations l10n,
  String? illustrationUrl,
  @visibleForTesting ImageProvider Function(String url) illustrationProvider =
      CachedNetworkImageProvider.new,
}) async {
  // In parallel: neither waits for the other. The logo is in the image cache
  // once resolved, it then paints at once.
  final (_, illustration) = await (
    precacheImage(Assets.logo.wishyLogo.provider(), context),
    _loadIllustration(illustrationUrl, illustrationProvider),
  ).wait;
  try {
    return await renderWidgetToPng(
      YearRecapShareImage(
        recap: recap,
        l10n: l10n,
        illustration: illustration,
      ),
      size: YearRecapShareImage.logicalSize,
      pixelRatio: YearRecapShareImage.pixelRatio,
    );
  } finally {
    illustration.dispose();
  }
}

Future<ui.Image> _loadIllustration(
  String? url,
  ImageProvider Function(String url) providerFor,
) async {
  if (url != null) {
    try {
      return await _resolve(
        // Decoded at the size it is drawn at, not the full picture. Only the
        // height is given: the width follows, the picture is not distorted.
        ResizeImage.resizeIfNeeded(
          null,
          (YearRecapShareImage.illustrationHeight *
                  YearRecapShareImage.pixelRatio)
              .ceil(),
          providerFor(url),
        ),
        _illustrationTimeout,
      );
    } catch (_) {
      // The generic illustration is shown instead
    }
  }
  return _loadGenericIllustration();
}

/// The first frame of [provider], which the caller owns and disposes. Fails
/// when it takes more than [timeout] or cannot be loaded; the stream is let go
/// of in every case.
Future<ui.Image> _resolve(ImageProvider provider, Duration timeout) {
  final completer = Completer<ui.Image>();
  final stream = provider.resolve(ImageConfiguration.empty);
  Timer? timer;
  late final ImageStreamListener listener;
  void done() {
    timer?.cancel();
    stream.removeListener(listener);
  }

  // After the timeout the stream may still fail: a silent listener keeps that
  // late error from being reported as a Flutter error (we already fell back).
  // It goes away with the stream's first image or error.
  late final ImageStreamListener lateListener;
  lateListener = ImageStreamListener(
    (info, _) {
      info.dispose();
      stream.removeListener(lateListener);
    },
    onError: (_, __) => stream.removeListener(lateListener),
  );

  listener = ImageStreamListener(
    (info, _) {
      if (completer.isCompleted) {
        // Too late: the caller gave up
        info.dispose();
      } else {
        // The stream hands every listener a clone of its own: no need for
        // another one, the image is ours to dispose.
        completer.complete(info.image);
      }
      done();
    },
    onError: (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      done();
    },
  );
  timer = Timer(timeout, () {
    if (!completer.isCompleted) {
      completer.completeError(TimeoutException('Illustration', timeout));
    }
    // Swapped, not removed: the stream always has a listener for its error
    stream
      ..addListener(lateListener)
      ..removeListener(listener);
    timer?.cancel();
  });
  stream.addListener(listener);
  return completer.future;
}

/// The bundled SVG, drawn once at the pixel size of the share image.
Future<ui.Image> _loadGenericIllustration() async {
  final info = await vg.loadPicture(
    SvgAssetLoader(Assets.svg.noWishBoxHat),
    null,
  );
  try {
    final scale = YearRecapShareImage.illustrationHeight *
        YearRecapShareImage.pixelRatio /
        info.size.height;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
      ..scale(scale)
      ..drawPicture(info.picture);
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(
        (info.size.width * scale).ceil(),
        (info.size.height * scale).ceil(),
      );
    } finally {
      picture.dispose();
    }
  } finally {
    info.picture.dispose();
  }
}

/// Lays [widget] out at [size] in a render tree of its own, which is never
/// attached to a view: nothing shows on screen.
Future<Uint8List> renderWidgetToPng(
  Widget widget, {
  required Size size,
  required double pixelRatio,
}) async {
  final boundary = RenderRepaintBoundary();
  final renderView = RenderView(
    view: WidgetsBinding.instance.platformDispatcher.views.first,
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(size),
    ),
    child: RenderPositionedBox(child: boundary),
  );
  final pipelineOwner = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  final focusManager = FocusManager();
  final buildOwner = BuildOwner(focusManager: focusManager);
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.noScaling),
        child: DefaultTextStyle(
          style: const TextStyle(),
          child: widget,
        ),
      ),
    ),
  ).attachToRenderTree(buildOwner);
  try {
    buildOwner
      ..buildScope(root)
      ..finalizeTree();
    pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw StateError('The share image could not be encoded');
      }
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    // Unmounts the tree
    RenderObjectToWidgetAdapter<RenderBox>(container: boundary)
        .attachToRenderTree(buildOwner, root);
    buildOwner.finalizeTree();
    pipelineOwner.rootNode = null;
    renderView.dispose();
    pipelineOwner.dispose();
    focusManager.dispose();
  }
}
