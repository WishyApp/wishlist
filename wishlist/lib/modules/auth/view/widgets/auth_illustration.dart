import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Illustration at the top of a signup step. The drawings are tall and
/// narrow: they grow with the screen, while the birthday step still fits an
/// iPhone 8 without scrolling (200 there, as before).
class AuthIllustration extends StatelessWidget {
  const AuthIllustration({
    super.key,
    required this.asset,
    required this.screenHeight,
  });

  final String asset;

  /// Height of the screen left by the keyboard. Given by the caller, above its
  /// `Scaffold`: inside, the keyboard is already removed from the
  /// `MediaQuery` insets and the screen height ignores it. The pseudo step
  /// opens the keyboard on arrival, and the drawing must not be pushed out of
  /// sight.
  final double screenHeight;

  @override
  Widget build(BuildContext context) {
    // With the keyboard open on a very small screen (iPhone SE: 308 left), the
    // field scrolls into view and only about 60 of the drawing stays visible
    // whatever its size: a smaller drawing keeps most of it on screen.
    final minHeight = screenHeight < 400 ? 100.0 : 140.0;
    final height = (screenHeight * 0.36 - 40).clamp(minHeight, 320.0);

    return SvgPicture.asset(asset, height: height);
  }
}
