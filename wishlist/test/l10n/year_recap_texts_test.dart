import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/arb/app_localizations.dart';
import 'package:wishlist/modules/year_recap/year_recap_texts.dart';
import 'package:wishlist/shared/models/year_recap/year_recap.dart';

import '../fixtures/fake_year_recap.dart';

void main() {
  late AppLocalizations fr;
  late AppLocalizations en;

  setUp(() async {
    fr = await AppLocalizations.delegate.load(const Locale('fr'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  String stat(
    AppLocalizations l10n,
    YearRecapProfileKey key,
    YearRecapStats s,
  ) =>
      l10n.yearRecapProfileStat(fakeYearRecap(profile: key, stats: s));

  test('minimaliste: 0 and 1 are singular in French, 0 is plural in English',
      () {
    String text(AppLocalizations l, int n) => stat(
          l,
          YearRecapProfileKey.minimaliste,
          YearRecapStats(received: n),
        );

    expect(text(fr, 0), '0 wish reçu');
    expect(text(fr, 1), '1 wish reçu');
    expect(text(fr, 2), '2 wishs reçus');
    expect(text(en, 0), '0 wishes received');
    expect(text(en, 1), '1 wish received');
    expect(text(en, 5), '5 wishes received');
  });

  test('pere_noel_discret: offered and received have their own plurals', () {
    String text(AppLocalizations l, int offered, int received) => stat(
          l,
          YearRecapProfileKey.pereNoelDiscret,
          YearRecapStats(offered: offered, received: received),
        );

    expect(text(fr, 0, 0), '0 offert, 0 reçu');
    expect(text(fr, 1, 1), '1 offert, 1 reçu');
    expect(text(fr, 4, 2), '4 offerts, 2 reçus');
    expect(text(en, 1, 2), '1 given, 2 received');
  });

  test('every counted line has a singular and a plural', () {
    String text(YearRecapProfileKey key, YearRecapStats s) => stat(fr, key, s);

    expect(
      text(
        YearRecapProfileKey.rassembleur,
        const YearRecapStats(newFriends: 1),
      ),
      '1 nouvel ami',
    );
    expect(
      text(
        YearRecapProfileKey.rassembleur,
        const YearRecapStats(newFriends: 3),
      ),
      '3 nouveaux amis',
    );
    expect(
      text(
        YearRecapProfileKey.amiFidele,
        const YearRecapStats(maxOfferedSameFriend: 1),
      ),
      '1 cadeau pour la même personne',
    );
    expect(
      text(
        YearRecapProfileKey.dernierMoment,
        const YearRecapStats(),
      ),
      '0 cadeau réservé au dernier moment',
    );
    expect(
      text(
        YearRecapProfileKey.organise,
        const YearRecapStats(receivedOnPartyDay: 1),
      ),
      '1 wish coché le jour J',
    );
    expect(
      text(YearRecapProfileKey.reveur, const YearRecapStats()),
      '0 wish ajouté',
    );
  });

  test('patient: the days are plural too', () {
    String text(int days) => stat(
          fr,
          YearRecapProfileKey.patient,
          YearRecapStats(longestAwaited: fakeLongestAwaited(days: days)),
        );

    expect(text(1), '1 jour pour Casque');
    expect(text(185), '185 jours pour Casque');
  });

  test('no French text uses the middle dot of the inclusive writing', () {
    for (final key in YearRecapProfileKey.values) {
      expect(fr.yearRecapProfileTitle(key), isNot(contains('·')));
      expect(fr.yearRecapProfileTagline(key), isNot(contains('·')));
    }
  });
}
