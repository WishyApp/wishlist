import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/gen/fonts.gen.dart';
import 'package:wishlist/l10n/arb/app_localizations.dart';
import 'package:wishlist/modules/year_recap/year_recap_texts.dart';
import 'package:wishlist/shared/models/year_recap/year_recap.dart';
import 'package:wishlist/shared/theme/colors.dart';

/// The picture the user shares: "Ton année Wishy" as a story (9:16). It is
/// laid out at [logicalSize] and captured at a pixel ratio of 3, which gives a
/// 1080x1920 image. It never shows a friend's pseudo, a list name or a price:
/// only the profile and its figures.
class YearRecapShareImage extends StatelessWidget {
  const YearRecapShareImage({
    super.key,
    required this.recap,
    required this.l10n,
    required this.illustration,
  });

  static const logicalSize = Size(360, 640);
  static const pixelRatio = 3.0;
  static const illustrationHeight = 230.0;

  static const _background = AppColors.background;
  static const _ink = AppColors.darkGrey;
  static const _tagline = Color(0xFFC2622F);

  final YearRecapData recap;

  /// Passed in rather than read from the context: the picture is rendered
  /// outside of the app's widget tree.
  final AppLocalizations l10n;

  /// Already decoded, so that the capture never waits for it.
  final ui.Image illustration;

  TextStyle _style(double size, FontWeight weight, Color color) => TextStyle(
        fontFamily: FontFamily.plusJakartaSans,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.15,
      );

  @override
  Widget build(BuildContext context) {
    final key = recap.profile.key;
    final title = l10n.yearRecapProfileTitle(key);
    return SizedBox.fromSize(
      size: logicalSize,
      child: ColoredBox(
        color: _background,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Assets.logo.wishyLogo.image(height: 28),
                  const Spacer(),
                  Text(
                    l10n.yearRecapShareImageHeader('${recap.year}'),
                    style: _style(14, FontWeight.w700, _ink),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              Text(
                l10n.yearRecapProfileIntro,
                style: _style(16, FontWeight.w600, AppColors.makara),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                // The longest titles (a pair of long words) shrink to fit
                style:
                    _style(title.length > 26 ? 28 : 36, FontWeight.w800, _ink),
              ),
              Expanded(
                child: Center(
                  child: SizedBox(
                    height: illustrationHeight,
                    child: RawImage(
                      image: illustration,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
              Transform.rotate(
                angle: -0.035,
                child: Text(
                  l10n.yearRecapProfileTagline(key),
                  textAlign: TextAlign.center,
                  style: _style(19, FontWeight.w800, _tagline),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Text(
                      l10n.yearRecapProfileStat(recap),
                      textAlign: TextAlign.center,
                      style: _style(15, FontWeight.w800, _ink),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                '${l10n.yearRecapShareFooter} wishy-app.fr',
                textAlign: TextAlign.center,
                style: _style(13, FontWeight.w700, _ink),
              ),
              const SizedBox(height: 10),
              const SizedBox(
                height: 2,
                child: ColoredBox(color: _ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
