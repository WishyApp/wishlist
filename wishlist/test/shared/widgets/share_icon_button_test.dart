import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:wishlist/shared/utils/share_utils.dart';
import 'package:wishlist/shared/widgets/share_icon_button.dart';

import '../../pump_app.dart';

class _FakeSharePlatform extends SharePlatform {
  final shared = <ShareParams>[];

  @override
  Future<ShareResult> share(ShareParams params) async {
    shared.add(params);
    return ShareResult.unavailable;
  }
}

void main() {
  late _FakeSharePlatform platform;

  setUp(() {
    platform = _FakeSharePlatform();
    sharePlusOverride = SharePlus.custom(platform);
  });

  tearDown(() => sharePlusOverride = null);

  testWidgets('share anchors the share sheet on the button (iPad)', (
    tester,
  ) async {
    await tester.pumpApp(
      Scaffold(
        appBar: AppBar(
          actions: [
            ShareIconButton(params: () => ShareParams(text: 'Noël')),
          ],
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.share));

    final button = find.ancestor(
      of: find.byIcon(Icons.share),
      matching: find.byType(IconButton),
    );
    expect(platform.shared, hasLength(1));
    expect(platform.shared.single.text, 'Noël');
    expect(platform.shared.single.sharePositionOrigin, tester.getRect(button));
    expect(platform.shared.single.sharePositionOrigin!.isEmpty, isFalse);
  });

  testWidgets('share failure is reported to onError', (tester) async {
    Object? error;
    await tester.pumpApp(
      Scaffold(
        body: ShareIconButton(
          // Neither text, uri nor files: share_plus throws
          params: ShareParams.new,
          onError: (e) => error = e,
        ),
      ),
    );
    sharePlusOverride = null;

    await tester.tap(find.byIcon(Icons.share));

    expect(error, isA<ArgumentError>());
  });
}
