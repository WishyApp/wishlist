import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Replaces [SharePlus.instance] in tests
@visibleForTesting
SharePlus? sharePlusOverride;

/// Global area of the widget owning [context]: the iPad share sheet is a
/// popover and needs it as its anchor
Rect? shareOriginOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) {
    return null;
  }
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Shares [params] anchored on the widget owning [context] (use the context of
/// the share button), unless [ShareParams.sharePositionOrigin] is already set.
/// Always share through it: without an origin the share fails on iPad.
Future<ShareResult> shareFrom(BuildContext context, ShareParams params) {
  return (sharePlusOverride ?? SharePlus.instance).share(
    // ShareParams has no copyWith
    ShareParams(
      text: params.text,
      subject: params.subject,
      title: params.title,
      previewThumbnail: params.previewThumbnail,
      sharePositionOrigin: params.sharePositionOrigin ?? shareOriginOf(context),
      uri: params.uri,
      files: params.files,
      fileNameOverrides: params.fileNameOverrides,
      downloadFallbackEnabled: params.downloadFallbackEnabled,
      mailToFallbackEnabled: params.mailToFallbackEnabled,
      excludedCupertinoActivities: params.excludedCupertinoActivities,
    ),
  );
}
