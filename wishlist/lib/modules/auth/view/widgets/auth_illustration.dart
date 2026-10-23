import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Illustration at the top of a signup step. The drawings are tall and
/// narrow: they grow with the screen, while the birthday step still fits an
/// iPhone 8 without scrolling (200 there, as before).
class AuthIllustration extends StatelessWidget {
  const AuthIllustration({super.key, required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    final height =
        (MediaQuery.sizeOf(context).height * 0.36 - 40).clamp(140.0, 320.0);

    return SvgPicture.asset(asset, height: height);
  }
}
