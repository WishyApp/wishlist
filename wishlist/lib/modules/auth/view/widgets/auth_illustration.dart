import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Illustration at the top of a signup step. The drawings are tall and
/// narrow: they get most of the space the short texts leave, and the step
/// still fits an iPhone 8 without scrolling.
class AuthIllustration extends StatelessWidget {
  const AuthIllustration({super.key, required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    final height =
        (MediaQuery.sizeOf(context).height * 0.3).clamp(140.0, 260.0);

    return SvgPicture.asset(asset, height: height);
  }
}
