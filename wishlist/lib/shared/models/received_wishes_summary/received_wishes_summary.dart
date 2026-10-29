import 'package:flutter/foundation.dart';

/// What the home screen shows of the wishes a user received: how many, and the
/// day of the latest one.
@immutable
class ReceivedWishesSummary {
  const ReceivedWishesSummary({required this.count, this.latestCompletedAt});

  /// Nothing received.
  const ReceivedWishesSummary.empty() : this(count: 0);

  /// Number of received wishes (rows, not quantities).
  final int count;

  /// Day of the latest one, null without any.
  final DateTime? latestCompletedAt;

  @override
  bool operator ==(Object other) =>
      other is ReceivedWishesSummary &&
      other.count == count &&
      other.latestCompletedAt == latestCompletedAt;

  @override
  int get hashCode => Object.hash(count, latestCompletedAt);

  @override
  String toString() =>
      'ReceivedWishesSummary(count: $count, latest: $latestCompletedAt)';
}
