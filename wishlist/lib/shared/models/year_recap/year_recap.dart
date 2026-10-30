import 'package:freezed_annotation/freezed_annotation.dart';

part 'year_recap.freezed.dart';
part 'year_recap.g.dart';

/// The profile the server gives to a user for a year. A key this version of
/// the app does not know (a profile added since) is shown as [minimaliste].
enum YearRecapProfileKey {
  patient,
  pereNoelDiscret,
  gate,
  equilibriste,
  reveur,
  rassembleur,
  amiFidele,
  dernierMoment,
  organise,
  minimaliste;

  /// The key as the server writes it (snake case).
  String get serverKey => switch (this) {
        pereNoelDiscret => 'pere_noel_discret',
        amiFidele => 'ami_fidele',
        dernierMoment => 'dernier_moment',
        _ => name,
      };

  static YearRecapProfileKey fromServerKey(Object? key) {
    for (final value in values) {
      if (value.serverKey == key) {
        return value;
      }
    }
    return minimaliste;
  }

  static String toServerKey(YearRecapProfileKey key) => key.serverKey;
}

/// The wish received during the year that waited the longest on the list.
@freezed
class YearRecapLongestAwaited with _$YearRecapLongestAwaited {
  const factory YearRecapLongestAwaited({
    @JsonKey(name: 'wish_id') required int wishId,
    @JsonKey(name: 'wish_name') required String wishName,
    @JsonKey(name: 'created_on') required DateTime createdOn,
    @JsonKey(name: 'completed_on') required DateTime completedOn,
    required int days,
  }) = _YearRecapLongestAwaited;

  factory YearRecapLongestAwaited.fromJson(Map<String, dynamic> json) =>
      _$YearRecapLongestAwaitedFromJson(json);
}

@freezed
class YearRecapStats with _$YearRecapStats {
  const factory YearRecapStats({
    @Default(0) int received,
    @Default(0) int offered,
    @JsonKey(name: 'longest_awaited') YearRecapLongestAwaited? longestAwaited,
    @JsonKey(name: 'wishes_added') @Default(0) int wishesAdded,
    @JsonKey(name: 'new_friends') @Default(0) int newFriends,
    @JsonKey(name: 'max_offered_same_friend')
    @Default(0)
    int maxOfferedSameFriend,
    @JsonKey(name: 'last_minute_bookings') @Default(0) int lastMinuteBookings,
    @JsonKey(name: 'bookings_total') @Default(0) int bookingsTotal,
    @JsonKey(name: 'last_minute_share') @Default(0) num lastMinuteShare,
    @JsonKey(name: 'received_on_party_day') @Default(0) int receivedOnPartyDay,
  }) = _YearRecapStats;

  factory YearRecapStats.fromJson(Map<String, dynamic> json) =>
      _$YearRecapStatsFromJson(json);
}

@freezed
class YearRecapProfile with _$YearRecapProfile {
  const factory YearRecapProfile({
    @JsonKey(
      fromJson: YearRecapProfileKey.fromServerKey,
      toJson: YearRecapProfileKey.toServerKey,
    )
    required YearRecapProfileKey key,
    @Default(0) num score,

    /// Path in the public bucket `year-recap-illustrations`, null until the
    /// illustration is uploaded.
    @JsonKey(name: 'illustration_path') String? illustrationPath,
  }) = _YearRecapProfile;

  factory YearRecapProfile.fromJson(Map<String, dynamic> json) =>
      _$YearRecapProfileFromJson(json);
}

/// What `get_my_year_recap` returns: the figures of a year and the profile
/// they earn. The card "Ton année Wishy", its page and the share image are
/// all built from it.
@freezed
class YearRecapData with _$YearRecapData {
  const factory YearRecapData({
    required int year,
    required YearRecapStats stats,
    required YearRecapProfile profile,

    /// The pseudo of the friend the user offered the most to, null when nothing
    /// was offered or when several friends tie.
    @JsonKey(name: 'most_gifted_friend') String? mostGiftedFriend,
  }) = _YearRecapData;

  factory YearRecapData.fromJson(Map<String, dynamic> json) =>
      _$YearRecapDataFromJson(json);
}
