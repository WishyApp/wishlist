import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current time, overridable in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
