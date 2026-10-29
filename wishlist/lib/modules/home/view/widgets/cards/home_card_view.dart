import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/friends/view/widgets/add_friend_bottom_sheet.dart';
import 'package:wishlist/modules/home/cards/home_card_candidate.dart';
import 'package:wishlist/modules/wishs/view/screens/consult_wish_screen.dart';
import 'package:wishlist/shared/infra/clock_provider.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_streams_providers.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/utils/relative_date_utils.dart';
import 'package:wishlist/shared/widgets/dialogs/create_dialog.dart';

/// Corner radius of a card.
const homeCardRadius = 22.0;

/// The outline of a card of this [tone], if it has one.
Color? homeCardBorderColor(HomeCardTone tone) => _Palette.of(tone).border;
const _onboardingSteps = 4;

/// One card of the home stack: an illustration, an overline, a title, a text,
/// one action button and a cross to hide it. The look follows
/// [HomeCardCandidate.tone].
class HomeCardView extends ConsumerWidget {
  const HomeCardView({
    super.key,
    required this.card,
    required this.onHide,
    this.flat = false,
  });

  final HomeCardCandidate card;

  /// Called by the cross (shown only on a dismissable card).
  final VoidCallback onHide;

  /// No radius and no border: the card slides in a slot that gives its shape
  /// (see `HomeCardStack`), so that nothing shows at its own corners.
  final bool flat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final spec = _specOf(context, ref);
    final palette = _Palette.of(card.tone);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: flat ? null : BorderRadius.circular(homeCardRadius),
        border: flat || palette.border == null
            ? null
            : Border.all(color: palette.border!),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 4, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              // The same height with or without the cross
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  if (spec.badge case final badge?) ...[
                    _Badge(badge: badge, palette: palette),
                    const Gap(8),
                  ],
                  Expanded(
                    child: Text(
                      spec.overline,
                      style: AppTextStyles.tiny.copyWith(
                        color: palette.secondaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (spec.step case final step?) ...[
                    const Gap(8),
                    _StepDots(step: step, palette: palette),
                  ],
                  if (card.dismissable)
                    // 48 px to touch, the icon stays small
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                      iconSize: 18,
                      tooltip: l10n.homeCardHide,
                      color: palette.secondaryText,
                      onPressed: onHide,
                      icon: const Icon(Icons.close),
                    )
                  else
                    const Gap(8),
                ],
              ),
            ),
            const Gap(2),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spec.title,
                          style: AppTextStyles.small.copyWith(
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                          ),
                        ),
                        if (spec.body case final body?) ...[
                          const Gap(4),
                          Text(
                            body,
                            style: AppTextStyles.smaller.copyWith(
                              color: palette.secondaryText,
                            ),
                          ),
                        ],
                        if (spec.actionLabel case final label?) ...[
                          const Gap(12),
                          ElevatedButton(
                            onPressed: spec.onAction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: palette.button,
                              foregroundColor: palette.buttonText,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              label,
                              style: AppTextStyles.smaller.copyWith(
                                fontWeight: FontWeight.w700,
                                color: palette.buttonText,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SvgPicture.asset(spec.illustration, width: 72, height: 72),
                const Gap(8),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _CardSpec _specOf(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();

    switch (card.content) {
      case FriendBirthdayToday(:final friend):
        final id = friend.user.id;
        return _CardSpec(
          overline: l10n.homeCardFriendBirthdayTodayOverline,
          title: l10n.homeCardFriendBirthdayTodayTitle(friend.profile.pseudo),
          actionLabel: l10n.homeCardSeeTheirList,
          onAction: () => FriendDetailsRoute(id).push(context),
          illustration: Assets.svg.birthday,
        );
      case FriendBirthdaySoon(:final friend, :final birthday, :final days):
        final id = friend.user.id;
        return _CardSpec(
          overline: l10n.friendBirthdayWithCountdown(
            birthday.format(locale),
            days,
          ),
          title: l10n.homeCardFriendBirthdaySoonTitle(friend.profile.pseudo),
          actionLabel: l10n.homeCardSeeTheirWishlists,
          onAction: () => FriendDetailsRoute(id).push(context),
          illustration: Assets.svg.birthday,
        );
      case AfterParty(:final occasion, :final daysAgo, :final wishlist):
        return _CardSpec(
          overline: occasion == AfterPartyOccasion.birthday
              ? l10n.homeCardAfterPartyBirthdayOverline(daysAgo)
              : l10n.homeCardAfterPartyChristmasOverline(daysAgo),
          title: l10n.homeCardAfterPartyTitle,
          body: wishlist == null
              ? occasion == AfterPartyOccasion.birthday
                  ? l10n.homeCardAfterPartyNoListBirthday
                  : l10n.homeCardAfterPartyNoListChristmas
              : null,
          actionLabel: wishlist == null ? null : l10n.homeCardAfterPartyAction,
          onAction: wishlist == null
              ? null
              : () => WishlistRoute(wishlistId: wishlist.id).push(context),
          illustration: Assets.svg.noWishBoxHat,
        );
      case BookedReminder(:final booking, :final occasion, :final days):
        return _CardSpec(
          overline: occasion == ReminderOccasion.christmas
              ? l10n.homeCardBookedReminderChristmasOverline(days)
              : l10n.homeCardBookedReminderBirthdayOverline(
                  booking.ownerPseudo,
                  days,
                ),
          title: l10n.homeCardBookedReminderTitle(booking.wish.name),
          actionLabel: l10n.homeCardSeeTheWish,
          onAction: () => ConsultWishRoute(
            booking.wish.wishlistId,
            booking.wish.id,
            wishIds: [booking.wish.id],
            // As the Booked tab opens it
            quantityDisplay: WishQuantityDisplay.myBooked,
          ).push(context),
          illustration: Assets.svg.noWishBag,
        );
      case BookedWishRemoved(:final removal, :final canOpenList):
        final hasPseudo = removal.ownerPseudo.isNotEmpty;
        return _CardSpec(
          overline: hasPseudo
              ? l10n.homeCardRemovedOverline(removal.ownerPseudo)
              : l10n.homeCardRemovedOverlineNoPseudo,
          badge: const _BadgeText('!'),
          title: hasPseudo
              ? l10n.homeCardRemovedTitle(
                  removal.ownerPseudo,
                  removal.wishName,
                )
              : l10n.homeCardRemovedTitleNoPseudo,
          body: canOpenList
              ? l10n.homeCardRemovedBody
              : l10n.homeCardRemovedBodyNoList,
          actionLabel: canOpenList ? l10n.homeCardSeeTheirList : null,
          onAction: canOpenList
              ? () => FriendDetailsRoute(removal.ownerId).push(context)
              : null,
          illustration: Assets.svg.noWishFlashlight,
        );
      case FriendAccepted(:final friend, :final acceptedAt):
        final id = friend.user.id;
        return _CardSpec(
          overline: formatRelativeDate(
            l10n,
            acceptedAt,
            now: ref.watch(clockProvider)(),
            locale: locale,
          ),
          badge: const _BadgeIcon(Icons.check),
          title: l10n.homeCardAcceptedTitle(friend.profile.pseudo),
          actionLabel: l10n.homeCardSeeTheirWishlists,
          onAction: () => FriendDetailsRoute(id).push(context),
          illustration: Assets.svg.noFriend,
        );
      case Christmas(:final days, :final wishlist):
        return _christmasSpec(context, ref, days, wishlist);
      case Onboarding(:final step):
        return _onboardingSpec(context, ref, step);
    }
  }

  _CardSpec _christmasSpec(
    BuildContext context,
    WidgetRef ref,
    int days,
    Wishlist? wishlist,
  ) {
    final l10n = context.l10n;
    if (wishlist == null) {
      return _CardSpec(
        overline: l10n.homeCardChristmasOverline(days),
        title: l10n.homeCardChristmasNoListTitle,
        actionLabel: l10n.homeCardChristmasNoListAction,
        onAction: () => showCreateDialog(context, ref),
        illustration: Assets.svg.noWishBoxHat,
      );
    }
    final count = ref
        .watch(watchWishsFromWishlistProvider(wishlist.id))
        .valueOrNull
        ?.length;
    return _CardSpec(
      overline: l10n.homeCardChristmasOverline(days),
      // The count is left out while the wishes load, or if they cannot be.
      title: count == null
          ? l10n.homeCardChristmasListTitleNoCount(wishlist.name)
          : l10n.homeCardChristmasListTitle(wishlist.name, count),
      actionLabel: l10n.homeCardChristmasListAction,
      onAction: () => WishlistRoute(wishlistId: wishlist.id).push(context),
      illustration: Assets.svg.noWishBoxHat,
    );
  }

  _CardSpec _onboardingSpec(
    BuildContext context,
    WidgetRef ref,
    OnboardingStep step,
  ) {
    final l10n = context.l10n;
    final number = step.index + 1;
    final overline = l10n.homeCardOnboardingStep(number, _onboardingSteps);
    switch (step) {
      case OnboardingStep.firstWishlist:
        return _CardSpec(
          overline: overline,
          step: number,
          title: l10n.homeCardOnboardingWishlistTitle,
          actionLabel: l10n.homeCardOnboardingWishlistAction,
          onAction: () => showCreateDialog(context, ref),
          illustration: Assets.svg.noWishlist,
        );
      case OnboardingStep.firstFriend:
        return _CardSpec(
          overline: overline,
          step: number,
          title: l10n.homeCardOnboardingFriendTitle,
          actionLabel: l10n.homeCardOnboardingFriendAction,
          onAction: () => showAddFriendBottomSheet(context),
          illustration: Assets.svg.noFriend,
        );
      case OnboardingStep.birthday:
        return _CardSpec(
          overline: overline,
          step: number,
          title: l10n.homeCardOnboardingBirthdayTitle,
          actionLabel: l10n.homeCardOnboardingBirthdayAction,
          onAction: () => ChangeBirthdayRoute().push(context),
          illustration: Assets.svg.birthday,
        );
      case OnboardingStep.photo:
        return _CardSpec(
          overline: overline,
          step: number,
          title: l10n.homeCardOnboardingPhotoTitle,
          actionLabel: l10n.homeCardOnboardingPhotoAction,
          onAction: () => EditProfileRoute().push(context),
          illustration: Assets.svg.pseudo,
        );
    }
  }
}

/// What a card shows, worked out from its content.
class _CardSpec {
  const _CardSpec({
    required this.overline,
    required this.title,
    required this.illustration,
    this.body,
    this.actionLabel,
    this.onAction,
    this.badge,
    this.step,
  });

  final String overline;
  final String title;
  final String illustration;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Icon pill next to the overline (alerts).
  final _BadgeContent? badge;

  /// Current onboarding step (1-based), drawn as dots.
  final int? step;
}

sealed class _BadgeContent {
  const _BadgeContent();
}

final class _BadgeText extends _BadgeContent {
  const _BadgeText(this.text);
  final String text;
}

final class _BadgeIcon extends _BadgeContent {
  const _BadgeIcon(this.icon);
  final IconData icon;
}

class _Badge extends StatelessWidget {
  const _Badge({required this.badge, required this.palette});

  final _BadgeContent badge;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.badge,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: 22,
        child: Center(
          child: switch (badge) {
            _BadgeText(:final text) => Text(
                text,
                style: AppTextStyles.tiny.copyWith(
                  fontWeight: FontWeight.w800,
                  color: palette.badgeContent,
                ),
              ),
            _BadgeIcon(:final icon) =>
              Icon(icon, size: 14, color: palette.badgeContent),
          },
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.palette});

  final int step;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= _onboardingSteps; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= step ? palette.button : palette.dotOff,
              ),
              child: const SizedBox.square(dimension: 6),
            ),
          ),
      ],
    );
  }
}

class _Palette {
  const _Palette({
    required this.background,
    required this.text,
    required this.secondaryText,
    required this.button,
    required this.buttonText,
    required this.badge,
    required this.badgeContent,
    required this.dotOff,
    this.border,
  });

  factory _Palette.of(HomeCardTone tone) {
    switch (tone) {
      case HomeCardTone.light:
        return const _Palette(
          background: Colors.white,
          border: AppColors.gainsboro,
          text: AppColors.darkGrey,
          secondaryText: AppColors.makara,
          button: AppColors.primary,
          buttonText: Colors.white,
          badge: AppColors.gainsboro,
          badgeContent: AppColors.darkOrange,
          dotOff: AppColors.gainsboro,
        );
      case HomeCardTone.highlighted:
        return const _Palette(
          background: AppColors.primary,
          text: Colors.white,
          secondaryText: Colors.white,
          button: AppColors.darkGrey,
          buttonText: Colors.white,
          badge: Colors.white,
          badgeContent: AppColors.darkOrange,
          dotOff: Color(0x66FFFFFF),
        );
      case HomeCardTone.dark:
        return const _Palette(
          background: AppColors.darkGrey,
          text: Colors.white,
          secondaryText: AppColors.pastelGray,
          button: AppColors.primary,
          buttonText: Colors.white,
          badge: AppColors.primary,
          badgeContent: Colors.white,
          dotOff: AppColors.makara,
        );
    }
  }

  final Color background;
  final Color? border;
  final Color text;
  final Color secondaryText;
  final Color button;
  final Color buttonText;
  final Color badge;
  final Color badgeContent;
  final Color dotOff;
}
