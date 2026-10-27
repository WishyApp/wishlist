import 'package:flutter/material.dart';
import 'package:wishlist/shared/theme/colors.dart';

Future<void> showAppBottomSheet(
  BuildContext context, {
  required Widget body,
  bool expandToFillHeight = true,
}) async {
  const radius = Radius.circular(25);
  // Ensure the theme is the same as the one from the context passed,
  // not the one from the builder of showBarModalBottomSheet
  final theme = Theme.of(context);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    barrierColor: Colors.black54.withValues(alpha: 0.3),
    isScrollControlled: true,
    builder: (context) {
      final themedBody = AnimatedTheme(
        data: theme,
        child: body,
      );

      if (expandToFillHeight) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = MediaQuery.sizeOf(context).height - 80;

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: radius,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: screenHeight,
                ),
                child: Scaffold(body: themedBody),
              ),
            );
          },
        );
      }

      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: radius),
        child: Material(
          color: AppColors.background,
          child: SafeArea(
            top: false,
            child: themedBody,
          ),
        ),
      );
    },
  );
}
