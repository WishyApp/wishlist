import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/l10n/arb/app_localizations.dart';
import 'package:wishlist/modules/year_recap/share/year_recap_share_image.dart';
import 'package:wishlist/shared/models/year_recap/year_recap.dart';

/// How long the illustration of the bucket may take before the generic one
/// replaces it.
const _illustrationTimeout = Duration(seconds: 8);

/// Draws [YearRecapShareImage] off-screen and returns it as a PNG of
/// 1080x1920. The illustration (the one at [illustrationUrl], or the bundled
/// generic one when there is none or it cannot be loaded) and the logo are
/// loaded before anything is drawn, so the capture never misses them.
Future<Uint8List> renderYearRecapShareImage({
  required BuildContext context,
  required YearRecapData recap,
  required AppLocalizations l10n,
  String? illustrationUrl,
}) async {
  // Both are in the image cache once resolved: the logo then paints at once
  await precacheImage(Assets.logo.wishyLogo.provider(), context);
  final illustration = await _loadIllustration(illustrationUrl);
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

Future<ui.Image> _loadIllustration(String? url) async {
  if (url != null) {
    try {
      return await _resolve(CachedNetworkImageProvider(url))
          .timeout(_illustrationTimeout);
    } catch (_) {
      // The generic illustration is shown instead
    }
  }
  return _loadGenericIllustration();
}

Future<ui.Image> _resolve(ImageProvider provider) {
  final completer = Completer<ui.Image>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) {
        completer.complete(info.image.clone());
      }
      stream.removeListener(listener);
    },
    onError: (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      stream.removeListener(listener);
    },
  );
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
  final buildOwner = BuildOwner(focusManager: FocusManager());
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
    renderView.dispose();
  }
}
