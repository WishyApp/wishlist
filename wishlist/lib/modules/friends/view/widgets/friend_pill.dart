import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/friends/view/widgets/base_avatar_pill.dart';
import 'package:wishlist/shared/infra/clock_provider.dart';
import 'package:wishlist/shared/infra/visible_birthdays_provider.dart';
import 'package:wishlist/shared/models/app_user.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

class FriendPill extends ConsumerWidget {
  const FriendPill({
    super.key,
    required this.appUser,
  });

  final AppUser appUser;

  void _onTap(BuildContext context) {
    FriendDetailsRoute(appUser.user.id).push(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textShadow = Shadow(
      color: AppColors.darkGrey.withValues(alpha: 0.3),
      offset: const Offset(2, 2),
      blurRadius: 5,
    );

    const textColor = AppColors.background;

    final birthday = ref.watch(friendBirthdayProvider(appUser.user.id));
    // Read at build time: a screen left open past midnight updates on its
    // next rebuild.
    final daysUntilBirthday = birthday?.upcomingIn(ref.watch(clockProvider)());

    return BaseAvatarPill(
      onTap: () => _onTap(context),
      backgroundColor: AppColors.primary,
      avatarBorderColor: AppColors.darkOrange,
      avatarUrl: appUser.profile.avatarUrl,
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            // The pseudo gives way to the badge, not the other way around
            Expanded(
              child: Text(
                appUser.profile.pseudo,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.large.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  shadows: [
                    textShadow,
                  ],
                ),
              ),
            ),
            if (daysUntilBirthday != null) ...[
              const SizedBox(width: 8),
              // A Row gives its fixed children unbounded width: cap the badge,
              // so that its text ellipsizes instead of overflowing.
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: constraints.maxWidth * 0.6),
                child: _BirthdayBadge(days: daysUntilBirthday),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cream chip on the orange pill: dark text on it stays readable.
class _BirthdayBadge extends StatelessWidget {
  const _BirthdayBadge({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cake_rounded,
            size: 16,
            color: AppColors.darkOrange,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              context.l10n.friendBirthdayBadge(days),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.smaller.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.darkGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
