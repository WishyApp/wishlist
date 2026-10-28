import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

/// Frame of the sign-in / sign-up screen, in three zones: the brand (logo and
/// name), the form, and the footer links at the bottom. The free space goes
/// between them; they scroll when they no longer fit.
///
/// Same approach as `SignupStepLayout`: the footer stays anchored at the
/// bottom of the screen, above the keyboard when it is open, as long as the
/// visible height leaves room for the rest.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.formKey,
    required this.child,
    required this.footer,
  });

  final GlobalKey<FormState> formKey;
  final Widget child;

  /// Secondary links, at the very bottom.
  final Widget footer;

  /// Below this visible height (scaled by the text size), the anchored footer
  /// would leave no room for the form: it scrolls with it instead (keyboard
  /// open on a small phone, landscape, very large text).
  static const _minAnchoredHeight = 560.0;

  static const _horizontalPadding = 32.0;

  /// Below this visible height, the logo shrinks to leave room for the form
  /// and both social buttons (sign-up on an iPhone 8).
  static const _compactHeight = 700.0;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.0);

    return Scaffold(
      body: SafeArea(
        child: AutofillGroup(
          child: Form(
            key: formKey,
            // The Scaffold shrinks its body when the keyboard opens: the
            // constraints give the height actually visible.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isAnchored =
                    constraints.maxHeight >= _minAnchoredHeight * textScale;
                final isCompact = constraints.maxHeight < _compactHeight;

                return Column(
                  children: [
                    Expanded(
                      child: CustomScrollView(
                        slivers: [
                          // At least the visible height, so that the spacers
                          // have room to spread; more when the zones do not
                          // fit. The padding goes inside: around the sliver,
                          // it would be added to that height and make a
                          // screen that fits scroll.
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                _horizontalPadding,
                                32,
                                _horizontalPadding,
                                16,
                              ),
                              child: Column(
                                children: [
                                  const Spacer(),
                                  Assets.logo.wishyLogo.image(
                                    height: isCompact ? 56 : 72,
                                    excludeFromSemantics: true,
                                  ),
                                  const Gap(8),
                                  Text(
                                    context.l10n.appTitle,
                                    style: AppTextStyles.title,
                                    textAlign: TextAlign.center,
                                  ),
                                  // Minimum gaps between the zones when space
                                  // is short
                                  const Gap(16),
                                  const Spacer(),
                                  child,
                                  const Gap(8),
                                  const Spacer(),
                                  if (!isAnchored) footer,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isAnchored)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          _horizontalPadding,
                          0,
                          _horizontalPadding,
                          16,
                        ),
                        child: footer,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
