import 'package:wishlist/l10n/arb/app_localizations.dart';
import 'package:wishlist/shared/models/year_recap/year_recap.dart';

/// The words of a profile: its title, its tagline and the line of figures
/// that justifies it.
extension YearRecapTexts on AppLocalizations {
  String yearRecapProfileTitle(YearRecapProfileKey key) => switch (key) {
        YearRecapProfileKey.patient => yearRecapProfilePatientTitle,
        YearRecapProfileKey.pereNoelDiscret =>
          yearRecapProfilePereNoelDiscretTitle,
        YearRecapProfileKey.gate => yearRecapProfileGateTitle,
        YearRecapProfileKey.equilibriste => yearRecapProfileEquilibristeTitle,
        YearRecapProfileKey.reveur => yearRecapProfileReveurTitle,
        YearRecapProfileKey.rassembleur => yearRecapProfileRassembleurTitle,
        YearRecapProfileKey.amiFidele => yearRecapProfileAmiFideleTitle,
        YearRecapProfileKey.dernierMoment => yearRecapProfileDernierMomentTitle,
        YearRecapProfileKey.organise => yearRecapProfileOrganiseTitle,
        YearRecapProfileKey.minimaliste => yearRecapProfileMinimalisteTitle,
      };

  String yearRecapProfileTagline(YearRecapProfileKey key) => switch (key) {
        YearRecapProfileKey.patient => yearRecapProfilePatientTagline,
        YearRecapProfileKey.pereNoelDiscret =>
          yearRecapProfilePereNoelDiscretTagline,
        YearRecapProfileKey.gate => yearRecapProfileGateTagline,
        YearRecapProfileKey.equilibriste => yearRecapProfileEquilibristeTagline,
        YearRecapProfileKey.reveur => yearRecapProfileReveurTagline,
        YearRecapProfileKey.rassembleur => yearRecapProfileRassembleurTagline,
        YearRecapProfileKey.amiFidele => yearRecapProfileAmiFideleTagline,
        YearRecapProfileKey.dernierMoment =>
          yearRecapProfileDernierMomentTagline,
        YearRecapProfileKey.organise => yearRecapProfileOrganiseTagline,
        YearRecapProfileKey.minimaliste => yearRecapProfileMinimalisteTagline,
      };

  /// The line of figures on the picture that is shared. It never names a wish:
  /// the patient profile shows its days only.
  String yearRecapShareStat(YearRecapData recap) {
    final awaited = recap.stats.longestAwaited;
    return recap.profile.key == YearRecapProfileKey.patient && awaited != null
        ? yearRecapStatPatientShare(awaited.days)
        : yearRecapProfileStat(recap);
  }

  String yearRecapProfileStat(YearRecapData recap) {
    final stats = recap.stats;
    return switch (recap.profile.key) {
      YearRecapProfileKey.patient => stats.longestAwaited == null
          ? yearRecapReceived(stats.received)
          : yearRecapStatPatient(
              stats.longestAwaited!.days,
              stats.longestAwaited!.wishName,
            ),
      YearRecapProfileKey.pereNoelDiscret ||
      YearRecapProfileKey.equilibriste =>
        yearRecapStatOfferedReceived(
          homeCardYearRecapOffered(stats.offered),
          yearRecapReceivedShort(stats.received),
        ),
      YearRecapProfileKey.gate ||
      YearRecapProfileKey.minimaliste =>
        yearRecapReceived(stats.received),
      YearRecapProfileKey.reveur => yearRecapStatReveur(stats.wishesAdded),
      YearRecapProfileKey.rassembleur =>
        yearRecapStatRassembleur(stats.newFriends),
      YearRecapProfileKey.amiFidele =>
        yearRecapStatAmiFidele(stats.maxOfferedSameFriend),
      YearRecapProfileKey.dernierMoment =>
        yearRecapStatDernierMoment(stats.lastMinuteBookings),
      YearRecapProfileKey.organise =>
        yearRecapStatOrganise(stats.receivedOnPartyDay),
    };
  }
}
