import 'package:flutter/material.dart';

/// Shared frame of the signup steps (pseudo, birthday): the content scrolls
/// and is centered when it fits, the actions stay anchored at the bottom of
/// the screen, above the keyboard when it is open.
class SignupStepLayout extends StatelessWidget {
  const SignupStepLayout({
    required this.content,
    required this.primaryAction,
    this.secondaryAction,
    super.key,
  });

  /// Illustration, title, explanation and input.
  final Widget content;

  /// The main button, at the very bottom.
  final Widget primaryAction;

  /// Optional button right above the main one.
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      // The padding is part of the scrollable extent
                      minHeight: constraints.maxHeight - 32 - 16,
                    ),
                    child: Center(child: content),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (secondaryAction case final secondaryAction?) ...[
                    secondaryAction,
                    const SizedBox(height: 8),
                  ],
                  primaryAction,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
