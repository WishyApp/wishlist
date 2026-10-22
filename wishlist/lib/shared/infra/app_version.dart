import 'package:flutter/foundation.dart';

/// A `major.minor.patch` version, compared numerically.
///
/// Only what the app version gate needs: `0.10.0` is after `0.3.0`, missing
/// parts count as 0 (`1.2` is `1.2.0`), and a build (`+10`) or pre-release
/// (`-beta`) suffix is ignored.
@immutable
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static final _pattern = RegExp(r'^(\d+)(?:\.(\d+))?(?:\.(\d+))?$');

  /// Null when [value] is not a version (empty, letters, more than three
  /// parts, negative numbers...): the version is then unknown.
  static AppVersion? tryParse(String? value) {
    if (value == null) {
      return null;
    }
    final core = value.trim().split(RegExp('[+-]')).first;
    final match = _pattern.firstMatch(core);
    if (match == null) {
      return null;
    }
    final parts = [
      for (var i = 1; i <= 3; i++) int.tryParse(match.group(i) ?? '0'),
    ];
    if (parts.contains(null)) {
      return null;
    }
    return AppVersion(parts[0]!, parts[1]!, parts[2]!);
  }

  @override
  int compareTo(AppVersion other) {
    final byMajor = major.compareTo(other.major);
    if (byMajor != 0) {
      return byMajor;
    }
    final byMinor = minor.compareTo(other.minor);
    if (byMinor != 0) {
      return byMinor;
    }
    return patch.compareTo(other.patch);
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}
