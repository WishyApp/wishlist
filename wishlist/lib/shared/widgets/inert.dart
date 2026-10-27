import 'package:flutter/widgets.dart';

/// Rend [child] inerte quand [inert] est vrai : il ne réagit plus aux touches
/// ni au focus clavier. Pour un widget masqué ou en train de disparaître qui
/// reste dans l'arbre.
class Inert extends StatelessWidget {
  const Inert({
    super.key,
    required this.inert,
    required this.child,
  });

  final bool inert;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: inert,
      child: ExcludeFocus(excluding: inert, child: child),
    );
  }
}

/// Layout d'un [AnimatedSwitcher] dont les enfants sortants sont [Inert]
/// pendant leur animation : ils gardent les callbacks de leur dernier build,
/// qui ne correspondent plus à l'état de l'écran.
AnimatedSwitcherLayoutBuilder inertSwitcherLayout({
  AlignmentGeometry alignment = Alignment.center,
  StackFit fit = StackFit.loose,
}) {
  // Même structure pour l'enfant entrant et les sortants, sous la clé que
  // leur donne l'AnimatedSwitcher : l'enfant qui sort garde son état
  return (currentChild, previousChildren) => Stack(
        alignment: alignment,
        fit: fit,
        children: [
          for (final child in previousChildren)
            Inert(key: child.key, inert: true, child: child),
          if (currentChild != null)
            Inert(key: currentChild.key, inert: false, child: currentChild),
        ],
      );
}
