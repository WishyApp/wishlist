import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:wishlist/l10n/arb/app_localizations.dart';
import 'package:wishlist/modules/year_recap/share/year_recap_sharer.dart';
import 'package:wishlist/shared/utils/share_utils.dart';

import '../../../fixtures/fake_year_recap.dart';

class _FakeSharePlatform extends SharePlatform {
  final shared = <ShareParams>[];

  @override
  Future<ShareResult> share(ShareParams params) async {
    shared.add(params);
    return ShareResult.unavailable;
  }
}

void main() {
  tearDown(() => sharePlusOverride = null);

  testWidgets('shares the picture and points the sheet to the origin (iPad)',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final platform = _FakeSharePlatform();
    sharePlusOverride = SharePlus.custom(platform);
    final params = platform.shared;
    final sharer = SharePlusYearRecapSharer(MockYearRecapRepository());
    const origin = Rect.fromLTWH(10, 20, 30, 40);

    await tester.runAsync(
      () => sharer.share(
        context,
        fakeYearRecap(),
        sharePositionOrigin: origin,
      ),
    );

    expect(params.single.sharePositionOrigin, origin);
    expect(params.single.files, hasLength(1));
    expect(params.single.files!.single.mimeType, 'image/png');
  });
}
