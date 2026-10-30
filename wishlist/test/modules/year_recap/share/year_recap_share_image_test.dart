import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/arb/app_localizations.dart';
import 'package:wishlist/modules/year_recap/share/year_recap_share_image.dart';
import 'package:wishlist/modules/year_recap/share/year_recap_share_renderer.dart';
import 'package:wishlist/shared/models/year_recap/year_recap.dart';

import '../../../fixtures/fake_year_recap.dart';

Future<ui.Image> tinyImage() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = Colors.orange,
  );
  return recorder.endRecording().toImage(4, 4);
}

void main() {
  final recap = fakeYearRecap(
    stats: YearRecapStats(
      received: 3,
      offered: 1,
      longestAwaited: fakeLongestAwaited(),
    ),
    profile: YearRecapProfileKey.patient,
  );

  Future<void> pumpImage(WidgetTester tester, AppLocalizations l10n) async {
    final image = (await tester.runAsync(tinyImage))!;
    addTearDown(image.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: YearRecapShareImage(
            recap: recap,
            l10n: l10n,
            illustration: image,
          ),
        ),
      ),
    );
  }

  testWidgets('shows the profile, its figures and the footer', (tester) async {
    await pumpImage(
      tester,
      await AppLocalizations.delegate.load(const Locale('fr')),
    );

    expect(find.text('Mon année 2026'), findsOneWidget);
    expect(find.text("En 2026, j'étais"), findsOneWidget);
    expect(find.text('Le marathonien / La marathonienne'), findsOneWidget);
    expect(
      find.text("Je l'ai voulu. J'ai attendu. Je l'ai eu."),
      findsOneWidget,
    );
    expect(find.text("185 jours d'attente"), findsOneWidget);
    expect(find.text("Et toi, t'es qui ? wishy-app.fr"), findsOneWidget);
  });

  testWidgets('is laid out at 360x640', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpImage(
      tester,
      await AppLocalizations.delegate.load(const Locale('fr')),
    );

    expect(
      tester.getSize(find.byType(YearRecapShareImage)),
      const Size(360, 640),
    );
  });

  testWidgets('never shows the name of a wish, a pseudo or a price',
      (tester) async {
    await pumpImage(
      tester,
      await AppLocalizations.delegate.load(const Locale('fr')),
    );

    // The patient profile counts days: the wish name stays on the page
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .join(' ');
    expect(texts, contains("185 jours d'attente"));
    expect(texts, isNot(contains('Casque')));
    expect(texts, isNot(contains('€')));
  });

  testWidgets('the figures wrap on two lines at most', (tester) async {
    await pumpImage(
      tester,
      await AppLocalizations.delegate.load(const Locale('fr')),
    );

    final stat = tester.widget<Text>(find.text("185 jours d'attente"));
    expect(stat.maxLines, 2);
    expect(stat.overflow, TextOverflow.ellipsis);
  });

  testWidgets('renders a PNG of 1080x1920 off-screen', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('fr'));
    await tester.runAsync(() async {
      final image = await tinyImage();
      final png = await renderWidgetToPng(
        YearRecapShareImage(recap: recap, l10n: l10n, illustration: image),
        size: YearRecapShareImage.logicalSize,
        pixelRatio: YearRecapShareImage.pixelRatio,
      );
      final codec = await ui.instantiateImageCodec(png);
      final frame = (await codec.getNextFrame()).image;

      expect(frame.width, 1080);
      expect(frame.height, 1920);
      frame.dispose();
      image.dispose();
    });
    // Nothing was added to the visible tree
    expect(find.byType(YearRecapShareImage), findsNothing);
  });
}
