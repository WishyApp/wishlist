import 'dart:async';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/modules/home/cards/year_recap_provider.dart';
import 'package:wishlist/modules/year_recap/share/year_recap_sharer.dart';
import 'package:wishlist/modules/year_recap/view/year_recap_screen.dart';
import 'package:wishlist/shared/infra/booked_wishes_realtime_provider.dart';
import 'package:wishlist/shared/models/year_recap/year_recap.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';
import '../../../fixtures/fake_year_recap.dart';
import '../../../pump_app.dart';

void main() {
  late FakeYearRecapSharer sharer;

  setUp(() {
    sharer = FakeYearRecapSharer();
  });

  Future<void> pumpRecap(
    WidgetTester tester,
    YearRecapData recap, {
    WindowConfigData? windowConfig,
    ImageProvider? illustration,
  }) async {
    await tester.pumpRouterApp(
      YearRecapRoute(year: 2026).location,
      windowConfig: windowConfig,
      overrides: [
        ...homeScreenOverrides(now: fakeNow),
        yearRecapFactsProvider.overrideWith((ref, year) async => recap),
        yearRecapRepositoryOverride(recap),
        yearRecapSharerProvider.overrideWithValue(sharer),
        if (illustration != null)
          yearRecapIllustrationProvider
              .overrideWith((ref, url) => illustration),
      ],
    );
    await tester.pumpAndSettle();
  }

  final fullRecap = fakeYearRecap(
    stats: YearRecapStats(
      received: 3,
      offered: 1,
      longestAwaited: fakeLongestAwaited(createdOn: DateTime(2024, 6, 2)),
    ),
    profile: YearRecapProfileKey.patient,
  );

  testWidgets('shows every block when the facts are all known', (tester) async {
    final recap = fullRecap.copyWith(mostGiftedFriend: 'Marie');
    await pumpRecap(tester, recap);

    expect(find.text('Ton année Wishy 2026'), findsOneWidget);
    expect(find.text('3 wishs reçus'), findsWidgets);
    expect(find.text('1 wish offert'), findsOneWidget);
    expect(
      find.text('Le plus attendu : Casque, sur ta liste depuis 2 juin 2024'),
      findsOneWidget,
    );
    expect(
      find.text('Ton ami le plus gâté : Marie'),
      findsOneWidget,
    );
    expect(find.byType(PrimaryButton), findsOneWidget);
    expect(find.text('Partager mon année'), findsWidgets);
    expect(find.text('Retour'), findsWidgets);
  });

  testWidgets('leaves out the blocks without data', (tester) async {
    await pumpRecap(
      tester,
      fakeYearRecap(stats: const YearRecapStats(received: 2)),
    );

    expect(find.text('2 wishs reçus'), findsWidgets);
    expect(find.text('0 wish offert'), findsOneWidget);
    expect(find.textContaining('Le plus attendu'), findsNothing);
    expect(find.textContaining('le plus gâté'), findsNothing);
  });

  group('profile block', () {
    final cases = <YearRecapProfileKey, (YearRecapStats, List<String>)>{
      YearRecapProfileKey.patient: (
        YearRecapStats(
          received: 1,
          longestAwaited: fakeLongestAwaited(),
        ),
        [
          'Le marathonien / La marathonienne',
          "Je l'ai voulu. J'ai attendu. Je l'ai eu.",
          '185 jours pour Casque',
        ],
      ),
      YearRecapProfileKey.pereNoelDiscret: (
        const YearRecapStats(offered: 4, received: 1),
        [
          'Le Père Noël / La Mère Noël',
          "Personne ne sait que c'était moi.",
          '4 offerts, 1 reçu',
        ],
      ),
      YearRecapProfileKey.gate: (
        const YearRecapStats(received: 6),
        [
          'Le gâté / La gâtée',
          "J'ai été très sage. Enfin, je crois.",
          '6 wishs reçus',
        ],
      ),
      YearRecapProfileKey.equilibriste: (
        const YearRecapStats(offered: 3, received: 3),
        ["L'équilibriste", 'Donnant, donnant.', '3 offerts, 3 reçus'],
      ),
      YearRecapProfileKey.reveur: (
        const YearRecapStats(wishesAdded: 12),
        [
          'Le rêveur / La rêveuse',
          "Rêver, c'est gratuit.",
          '12 wishs ajoutés',
        ],
      ),
      YearRecapProfileKey.rassembleur: (
        const YearRecapStats(newFriends: 5),
        [
          'Le rassembleur / La rassembleuse',
          'Plus on est de fous, plus on offre.',
          '5 nouveaux amis',
        ],
      ),
      YearRecapProfileKey.amiFidele: (
        const YearRecapStats(maxOfferedSameFriend: 4),
        [
          "L'ami fidèle / L'amie fidèle",
          'Cette personne se reconnaîtra.',
          '4 cadeaux pour la même personne',
        ],
      ),
      YearRecapProfileKey.dernierMoment: (
        const YearRecapStats(lastMinuteBookings: 3),
        [
          'Le roi / La reine du dernier moment',
          'Je travaille mieux sous pression.',
          '3 cadeaux réservés au dernier moment',
        ],
      ),
      YearRecapProfileKey.organise: (
        const YearRecapStats(receivedOnPartyDay: 2),
        [
          "L'organisé / L'organisée",
          'Papier cadeau à peine déchiré, liste déjà à jour.',
          '2 wishs cochés le jour J',
        ],
      ),
      YearRecapProfileKey.minimaliste: (
        const YearRecapStats(received: 1),
        ['Le minimaliste / La minimaliste', 'Peu, mais bien.', '1 wish reçu'],
      ),
    };

    for (final entry in cases.entries) {
      testWidgets('shows the title, tagline and figures of ${entry.key.name}',
          (tester) async {
        await pumpRecap(
          tester,
          fakeYearRecap(stats: entry.value.$1, profile: entry.key),
        );

        expect(find.text("Cette année, j'étais"), findsOneWidget);
        for (final text in entry.value.$2) {
          // The figures of a block below may say the same
          expect(find.text(text), findsWidgets, reason: text);
        }
      });
    }
  });

  testWidgets('shows the generic illustration without an illustration path',
      (tester) async {
    await pumpRecap(tester, fakeYearRecap());

    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('the profile title is a header for screen readers',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpRecap(tester, fullRecap);

    expect(
      tester.getSemantics(find.text('Le marathonien / La marathonienne')),
      matchesSemantics(
        isHeader: true,
        label: 'Le marathonien / La marathonienne',
      ),
    );
    handle.dispose();
  });

  testWidgets('the share button shares the recap', (tester) async {
    await pumpRecap(tester, fullRecap);

    tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed!();
    await tester.pumpAndSettle();

    expect(sharer.shared, [fullRecap]);
  });

  testWidgets('the share sheet points to the share button (iPad)',
      (tester) async {
    await pumpRecap(tester, fullRecap);

    tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed!();
    await tester.pumpAndSettle();

    expect(sharer.origins, [tester.getRect(find.byType(PrimaryButton))]);
  });

  testWidgets('a second tap while sharing is ignored', (tester) async {
    final gate = sharer.gate = Completer<void>();
    await pumpRecap(tester, fullRecap);

    final onPressed =
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed!;
    onPressed();
    await tester.pump();
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNull,
    );
    // A tap that was already on its way
    onPressed();
    await tester.pump();
    expect(sharer.shared, hasLength(1));

    gate.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('a reload while sharing keeps the page and the share running',
      (tester) async {
    final gate = sharer.gate = Completer<void>();
    await pumpRecap(tester, fullRecap);
    tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed!();
    await tester.pump();

    ProviderScope.containerOf(tester.element(find.byType(YearRecapScreen)))
        .invalidate(yearRecapFactsProvider);
    await tester.pump();

    // The page is still there (the spinner is the button's, sharing)
    expect(find.text('2 wishs reçus'), findsNothing);
    expect(find.text('3 wishs reçus'), findsWidgets);
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNull,
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(sharer.shared, hasLength(1));
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('the generic illustration replaces one that fails to load',
      (tester) async {
    await pumpRecap(
      tester,
      fakeYearRecap(illustrationPath: 'patient.png'),
      illustration: FailingImageProvider(),
    );

    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('a failing share shows an error and the button comes back',
      (tester) async {
    sharer.error = Exception('no share sheet');
    await pumpRecap(tester, fullRecap);

    tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed!();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNotNull,
    );
    // The snack-bar goes away by itself
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('the back button leaves the page', (tester) async {
    await pumpRecap(
      tester,
      fakeYearRecap(stats: const YearRecapStats(received: 2)),
    );

    tester.widget<SecondaryButton>(find.byType(SecondaryButton)).onPressed!();
    await tester.pumpAndSettle();

    expect(find.byType(YearRecapScreen), findsNothing);
  });

  testWidgets('retry reloads the recap and reopens the bookings that failed',
      (tester) async {
    var bookingLoads = 0;
    var recapLoads = 0;
    await tester.pumpRouterApp(
      YearRecapRoute(year: 2026).location,
      overrides: [
        ...homeScreenOverrides(now: fakeNow),
        bookedWishesRealtimeProvider.overrideWith((ref) {
          bookingLoads++;
          return bookingLoads == 1
              ? Stream.error(Exception('timeout'))
              : Stream.value(const IListConst([]));
        }),
        yearRecapFactsProvider.overrideWith((ref, year) async {
          // Watching the bookings is what a failed stream keeps serving
          await ref.watch(bookedWishesRealtimeProvider.future);
          recapLoads++;
          return fakeYearRecap(stats: const YearRecapStats(received: 1));
        }),
        yearRecapRepositoryOverride(fakeYearRecap()),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('1 wish reçu'), findsNothing);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(bookingLoads, 2);
    expect(recapLoads, 1);
    expect(find.text('1 wish reçu'), findsWidgets);
  });

  testAdaptiveWidgets('$YearRecapScreen golden test', (tester, variant) async {
    await pumpRecap(tester, fullRecap, windowConfig: variant);

    await tester.expectGolden<YearRecapScreen>(variant);
  });
}
