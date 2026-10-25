import 'package:flutter/widgets.dart';

/// Layout d'un [AnimatedSwitcher] dont les enfants sortants ne réagissent plus
/// aux touches ni au focus pendant leur animation : ils gardent les callbacks
/// de leur dernier build, qui ne correspondent plus à l'état de l'écran.
AnimatedSwitcherLayoutBuilder inertSwitcherLayout({
  AlignmentGeometry alignment = Alignment.center,
  StackFit fit = StackFit.loose,
}) {
  // Même structure pour l'enfant entrant et les sortants, sous la clé que
  // leur donne l'AnimatedSwitcher : l'enfant qui sort garde son état
  Widget wrap(Widget child, {required bool isOutgoing}) => IgnorePointer(
        key: child.key,
        ignoring: isOutgoing,
        child: ExcludeFocus(excluding: isOutgoing, child: child),
      );

  return (currentChild, previousChildren) => Stack(
        alignment: alignment,
        fit: fit,
        children: [
          for (final child in previousChildren) wrap(child, isOutgoing: true),
          if (currentChild != null) wrap(currentChild, isOutgoing: false),
        ],
      );
}
