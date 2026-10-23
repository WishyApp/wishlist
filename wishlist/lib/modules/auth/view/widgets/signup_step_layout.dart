import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/modules/auth/view/widgets/auth_illustration.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

/// Shared frame of the signup steps (pseudo, birthday), in two blocks: the
/// header (illustration, title, explanation) at the top, the input at the
/// bottom, right above the actions; the free space goes between the two. The
/// actions stay anchored at the bottom of the screen, above the keyboard when
/// it is open, and the blocks scroll when they no longer fit.
class SignupStepLayout extends StatelessWidget {
  const SignupStepLayout({
    required this.illustration,
    required this.title,
    required this.explanation,
    required this.input,
    required this.primaryAction,
    this.secondaryAction,
    super.key,
  });

  /// Asset of the illustration (`Assets.svg.*`).
  final String illustration;

  final String title;
  final String explanation;

  /// The field or picker of the step.
  final Widget input;

  /// The main button, at the very bottom.
  final Widget primaryAction;

  /// Optional button right above the main one.
  final Widget? secondaryAction;

  /// Below this visible height (scaled by the text size), the actions would
  /// leave no room for the blocks: they scroll with them instead of staying
  /// anchored (landscape with the keyboard open, very large text).
  static const _minAnchoredHeight = 250.0;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.0);

    // Read above the Scaffold, which removes the keyboard from its children
    final screenHeight = MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthIllustration(
          asset: illustration,
          screenHeight: screenHeight,
        ),
        const Gap(16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.titleSmall,
        ),
        const Gap(8),
        Text(
          explanation,
          textAlign: TextAlign.center,
          style: AppTextStyles.smaller.copyWith(color: AppColors.makara),
        ),
      ],
    );

    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (secondaryAction case final secondaryAction?) ...[
          secondaryAction,
          const SizedBox(height: 8),
        ],
        primaryAction,
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isAnchored =
                constraints.maxHeight >= _minAnchoredHeight * textScale;

            return Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      // At least the visible height, so that spaceBetween has
                      // room to spread; more when the blocks do not fit. The
                      // padding goes inside: around the sliver, it would be
                      // added to that height and make a screen that fits
                      // scroll.
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              header,
                              // Minimum gap between the blocks when space is
                              // short
                              const Gap(24),
                              if (isAnchored)
                                input
                              else
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [input, const Gap(24), actions],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAnchored)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
                    child: actions,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
