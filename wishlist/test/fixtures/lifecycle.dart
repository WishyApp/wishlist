import 'package:flutter/widgets.dart';

/// Goes to [target] through the states in between, the only transitions the
/// framework accepts (resumed, inactive, hidden, paused).
void walkLifecycleTo(AppLifecycleState target) {
  const path = [
    AppLifecycleState.resumed,
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ];
  final binding = WidgetsBinding.instance;
  var index = path.indexOf(binding.lifecycleState ?? AppLifecycleState.resumed);
  final end = path.indexOf(target);
  while (index != end) {
    index += end > index ? 1 : -1;
    binding.handleAppLifecycleStateChanged(path[index]);
  }
}
