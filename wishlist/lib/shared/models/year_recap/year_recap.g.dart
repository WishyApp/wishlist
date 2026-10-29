// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'year_recap.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$YearRecapLongestAwaitedImpl _$$YearRecapLongestAwaitedImplFromJson(
        Map<String, dynamic> json) =>
    _$YearRecapLongestAwaitedImpl(
      wishId: (json['wish_id'] as num).toInt(),
      wishName: json['wish_name'] as String,
      createdOn: DateTime.parse(json['created_on'] as String),
      completedOn: DateTime.parse(json['completed_on'] as String),
      days: (json['days'] as num).toInt(),
    );

Map<String, dynamic> _$$YearRecapLongestAwaitedImplToJson(
        _$YearRecapLongestAwaitedImpl instance) =>
    <String, dynamic>{
      'wish_id': instance.wishId,
      'wish_name': instance.wishName,
      'created_on': instance.createdOn.toIso8601String(),
      'completed_on': instance.completedOn.toIso8601String(),
      'days': instance.days,
    };

_$YearRecapStatsImpl _$$YearRecapStatsImplFromJson(Map<String, dynamic> json) =>
    _$YearRecapStatsImpl(
      received: (json['received'] as num?)?.toInt() ?? 0,
      offered: (json['offered'] as num?)?.toInt() ?? 0,
      longestAwaited: json['longest_awaited'] == null
          ? null
          : YearRecapLongestAwaited.fromJson(
              json['longest_awaited'] as Map<String, dynamic>),
      wishesAdded: (json['wishes_added'] as num?)?.toInt() ?? 0,
      newFriends: (json['new_friends'] as num?)?.toInt() ?? 0,
      maxOfferedSameFriend:
          (json['max_offered_same_friend'] as num?)?.toInt() ?? 0,
      lastMinuteBookings: (json['last_minute_bookings'] as num?)?.toInt() ?? 0,
      bookingsTotal: (json['bookings_total'] as num?)?.toInt() ?? 0,
      lastMinuteShare: json['last_minute_share'] as num? ?? 0,
      receivedOnPartyDay: (json['received_on_party_day'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$YearRecapStatsImplToJson(
        _$YearRecapStatsImpl instance) =>
    <String, dynamic>{
      'received': instance.received,
      'offered': instance.offered,
      'longest_awaited': instance.longestAwaited,
      'wishes_added': instance.wishesAdded,
      'new_friends': instance.newFriends,
      'max_offered_same_friend': instance.maxOfferedSameFriend,
      'last_minute_bookings': instance.lastMinuteBookings,
      'bookings_total': instance.bookingsTotal,
      'last_minute_share': instance.lastMinuteShare,
      'received_on_party_day': instance.receivedOnPartyDay,
    };

_$YearRecapProfileImpl _$$YearRecapProfileImplFromJson(
        Map<String, dynamic> json) =>
    _$YearRecapProfileImpl(
      key: YearRecapProfileKey.fromServerKey(json['key']),
      score: json['score'] as num? ?? 0,
      illustrationPath: json['illustration_path'] as String?,
    );

Map<String, dynamic> _$$YearRecapProfileImplToJson(
        _$YearRecapProfileImpl instance) =>
    <String, dynamic>{
      'key': YearRecapProfileKey.toServerKey(instance.key),
      'score': instance.score,
      'illustration_path': instance.illustrationPath,
    };

_$YearRecapDataImpl _$$YearRecapDataImplFromJson(Map<String, dynamic> json) =>
    _$YearRecapDataImpl(
      year: (json['year'] as num).toInt(),
      stats: YearRecapStats.fromJson(json['stats'] as Map<String, dynamic>),
      profile:
          YearRecapProfile.fromJson(json['profile'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$YearRecapDataImplToJson(_$YearRecapDataImpl instance) =>
    <String, dynamic>{
      'year': instance.year,
      'stats': instance.stats,
      'profile': instance.profile,
    };
