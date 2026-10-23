import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/friends/view/widgets/friend_details_app_bar.dart';
import 'package:wishlist/modules/friends/view/widgets/friend_pill.dart';
import 'package:wishlist/modules/wishs/view/screens/consult_wish_screen.dart';
import 'package:wishlist/shared/infra/completed_wishes_realtime_provider.dart';
import 'package:wishlist/shared/infra/friend_details_realtime_provider.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/models/friend_details/friend_details.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/page_layout_error/page_layout_error.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/theme/widgets/app_refresh_indicator.dart';
import 'package:wishlist/shared/theme/widgets/pill.dart';
import 'package:wishlist/shared/utils/app_user_utils.dart';
import 'package:wishlist/shared/utils/relative_date_utils.dart';
import 'package:wishlist/shared/utils/retry_providers_extension.dart';
import 'package:wishlist/shared/widgets/avatar/app_avatar.dart';
import 'package:wishlist/shared/widgets/wish_image.dart';
import 'package:wishlist/shared/widgets/wishlists_grid.dart';

class FriendDetailsScreen extends ConsumerWidget {
  const FriendDetailsScreen({super.key, required this.friendId});
  final String friendId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendDetails = ref.watch(friendDetailsRealtimeProvider(friendId));

    Future<void> refreshFriendDetails() async {
      ref.invalidate(friendDetailsRealtimeProvider(friendId));

      // Attendre que le nouveau stream soit initialisé
      await ref.read(friendDetailsRealtimeProvider(friendId).future);
    }

    final loadedDetails = friendDetails.valueOrNull;

    // The back button stays available whatever the state of the data
    return Scaffold(
      appBar: FriendDetailsAppBar(friend: loadedDetails?.appUser),
      body: friendDetails.when(
        data: (friendDetails) => SafeArea(
          // The list scrolls under the home indicator, its SliverSafeArea
          // keeps the last item clear of it
          bottom: false,
          child: _FriendDetailsScreen(
            friendDetails: friendDetails,
            onRefresh: refreshFriendDetails,
          ),
        ),
        loading: () => const SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => SafeArea(
          child: PageLayoutError(
            error: error,
            onRetry: () =>
                ref.retryFailed([friendDetailsRealtimeProvider(friendId)]),
            isRetrying:
                ref.isRetryingAny([friendDetailsRealtimeProvider(friendId)]),
          ),
        ),
      ),
    );
  }
}

const double _horizontalPadding = 30;

class _FriendDetailsScreen extends StatelessWidget {
  const _FriendDetailsScreen({
    required this.friendDetails,
    required this.onRefresh,
  });
  final FriendDetails friendDetails;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverSafeArea(
            top: false,
            left: false,
            right: false,
            sliver: SliverMainAxisGroup(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    _horizontalPadding,
                    16,
                    _horizontalPadding,
                    0,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Stats
                      _FriendStatsSection(friendDetails: friendDetails),
                      const Gap(24),

                      // Mutual friends
                      _MutualFriendsTitleAndSection(
                        friendDetails: friendDetails,
                      ),
                      const Gap(24),
                    ]),
                  ),
                ),

                // Completed wishes: the carousel runs edge to edge, so it
                // sits outside the horizontal padding
                SliverToBoxAdapter(
                  child: _FriendCompletedWishesSection(
                    friendId: friendDetails.appUser.user.id,
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    _horizontalPadding,
                    0,
                    _horizontalPadding,
                    16,
                  ),
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      const SliverToBoxAdapter(child: _WishlistsTitle()),
                      const SliverGap(12),
                      _WishlistsSection(friendDetails: friendDetails),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendStatsSection extends ConsumerWidget {
  const _FriendStatsSection({required this.friendDetails});
  final FriendDetails friendDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final nbWishlists = l10n.numberOfWishlists(friendDetails.nbWishlists);
    final nbWishs = l10n.numberOfWishs(friendDetails.nbWishs);
    final personalStats = '$nbWishlists | $nbWishs';
    const avatarSize = 80.0;

    return Row(
      children: [
        AppAvatar(
          avatarUrl: friendDetails.appUser.profile.avatarUrl,
          size: avatarSize,
        ),
        const Gap(16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              friendDetails.appUser.profile.pseudo,
              style: AppTextStyles.titleSmall,
            ),
            Text(
              personalStats,
              style: AppTextStyles.smaller.copyWith(
                color: AppColors.makara,
                height: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MutualFriendsTitleAndSection extends StatefulWidget {
  const _MutualFriendsTitleAndSection({required this.friendDetails});
  final FriendDetails friendDetails;

  @override
  State<_MutualFriendsTitleAndSection> createState() =>
      _MutualFriendsTitleAndSectionState();
}

class _MutualFriendsTitleAndSectionState
    extends State<_MutualFriendsTitleAndSection> {
  static const int _maxVisibleFriends = 3;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final mutualFriends =
        sortAppUsersByPseudo(widget.friendDetails.mutualFriends);
    final hasMoreFriends = mutualFriends.length > _maxVisibleFriends;
    final nbFriendsNotVisible = mutualFriends.length - _maxVisibleFriends;

    final seeAllAnimationDurationMs = nbFriendsNotVisible * 100;

    const hideAllAnimationDurationMs = 300;

    final animationDurationMs =
        _isExpanded ? seeAllAnimationDurationMs : hideAllAnimationDurationMs;

    final heightFactor = _isExpanded
        ? 1.0
        : min(_maxVisibleFriends, mutualFriends.length) / mutualFriends.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row with "See all" / "Hide" button
        Row(
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: ' ${l10n.friendDetailsMutualFriendsTitle}',
                    style: AppTextStyles.small.copyWith(
                      color: AppColors.makara,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (nbFriendsNotVisible > 0) ...[
                    const WidgetSpan(child: SizedBox(width: 2)),
                    TextSpan(
                      text: '(${mutualFriends.length})',
                      style: AppTextStyles.smaller.copyWith(
                        color: AppColors.makara,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (hasMoreFriends) ...[
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
                child: Text(
                  _isExpanded ? l10n.hide : l10n.seeAll,
                  style: AppTextStyles.smaller.copyWith(
                    color: AppColors.makara,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const Gap(12),
        // Mutual friends list
        if (mutualFriends.isEmpty)
          Center(
            child: Text(
              l10n.friendDetailsNoMutualFriends,
              style: AppTextStyles.smaller.copyWith(
                color: AppColors.makara,
              ),
            ),
          )
        else
          ClipRect(
            child: AnimatedAlign(
              duration: Duration(milliseconds: animationDurationMs),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              heightFactor: heightFactor,
              child: Column(
                children: [
                  for (final friend in mutualFriends)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FriendPill(appUser: friend),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _WishlistsTitle extends StatelessWidget {
  const _WishlistsTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      context.l10n.friendDetailsWishlistsTitle,
      style: AppTextStyles.small.copyWith(
        color: AppColors.makara,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _WishlistsSection extends StatelessWidget {
  const _WishlistsSection({required this.friendDetails});
  final FriendDetails friendDetails;

  @override
  Widget build(BuildContext context) {
    if (friendDetails.publicWishlists.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Text(
            context.l10n.noWishlist,
            style: AppTextStyles.smaller.copyWith(
              color: AppColors.makara,
            ),
          ),
        ),
      );
    }

    return WishlistsGrid(
      wishlists: friendDetails.publicWishlists.toList(),
      isReorderable: false,
    );
  }
}

class _FriendCompletedWishesSection extends ConsumerWidget {
  const _FriendCompletedWishesSection({required this.friendId});

  final String friendId;

  /// The most recent ones only: "See all" opens the whole list
  static const int _maxVisibleWishes = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final completedWishesAsync =
        ref.watch(completedWishesByUserRealtimeProvider(friendId));

    return completedWishesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (completedWishes) {
        if (completedWishes.isEmpty) {
          return const SizedBox.shrink();
        }

        final recentWishes = completedWishes
            .sort((a, b) => b.completedAt.compareTo(a.completedAt))
            .take(_maxVisibleWishes)
            .toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _horizontalPadding,
                ),
                child: Row(
                  children: [
                    // The title only gives way to "See all" on narrow screens
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              l10n.friendCompletedWishesTitle,
                              style: AppTextStyles.small.copyWith(
                                color: AppColors.makara,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Gap(8),
                          _CountBadge(count: completedWishes.length),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          FriendCompletedWishesRoute(friendId).push(
                        context,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.seeAllCompletedWishes,
                            style: AppTextStyles.smaller.copyWith(
                              color: AppColors.makara,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.makara,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: _horizontalPadding,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (index, item) in recentWishes.indexed) ...[
                      if (index > 0) const Gap(12),
                      _FriendCompletedWishCard(item: item),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: const BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: AppTextStyles.tiny.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FriendCompletedWishCard extends StatelessWidget {
  const _FriendCompletedWishCard({required this.item});

  final CompletedWishWithDetails item;

  static const double _width = 112;
  static const double _imageBorderRadius = 18;

  @override
  Widget build(BuildContext context) {
    final wish = item.wish;

    return SizedBox(
      width: _width,
      child: InkWell(
        onTap: () => ConsultWishRoute(
          wish.wishlistId,
          wish.id,
          wishIds: [wish.id],
          showActions: false,
          quantityDisplay: WishQuantityDisplay.completed,
        ).push(context),
        borderRadius: BorderRadius.circular(_imageBorderRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                WishImage(
                  iconUrl: wish.iconUrl,
                  size: _width,
                  borderRadius: _imageBorderRadius,
                ),
                const Positioned(
                  top: 8,
                  right: 8,
                  child: _CompletedBadge(),
                ),
                if (item.quantity > 1)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Pill(
                      text: 'x${item.quantity}',
                      backgroundColor: Theme.of(context).primaryColor,
                      textStyle: AppTextStyles.tiny,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                    ),
                  ),
              ],
            ),
            const Gap(8),
            Text(
              wish.name,
              style: AppTextStyles.smaller.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Gap(2),
            Text(
              formatRelativeDate(
                context.l10n,
                item.completedAt,
                now: DateTime.now(),
                locale: Localizations.localeOf(context).toString(),
              ),
              style: AppTextStyles.tiny.copyWith(color: AppColors.makara),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedBadge extends StatelessWidget {
  const _CompletedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.green,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(Icons.check, color: Colors.white, size: 14),
    );
  }
}
