import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.formKey,
    required this.child,
    required this.footer,
  });

  final GlobalKey<FormState> formKey;
  final Widget child;

  /// Secondary links, pinned at the bottom of the screen.
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    // The keyboard leaves little room: the footer then moves to the end of
    // the scrolling content instead of staying pinned above it, so that it
    // remains reachable (screen readers, hardware keyboards).
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
          child: AutofillGroup(
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  Expanded(
                    // On a tall screen the spare height goes around the
                    // brand and the form; when it doesn't fit (small screen,
                    // keyboard open) the spacers shrink to their gaps and it
                    // scrolls.
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              children: [
                                const Spacer(),
                                Assets.logo.wishyLogo.image(
                                  height: 72,
                                  excludeFromSemantics: true,
                                ),
                                const Gap(8),
                                Text(
                                  context.l10n.appTitle,
                                  style: AppTextStyles.title,
                                  textAlign: TextAlign.center,
                                ),
                                const Gap(24),
                                const Spacer(),
                                child,
                                const Gap(16),
                                const Spacer(),
                                if (isKeyboardOpen) footer,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Outside the scroll view: always visible, even on a small
                  // screen in sign-up.
                  if (!isKeyboardOpen) footer,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
