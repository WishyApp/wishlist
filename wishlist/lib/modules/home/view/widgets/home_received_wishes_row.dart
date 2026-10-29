import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/infra/clock_provider.dart';
import 'package:wishlist/shared/infra/completed_wishes_realtime_provider.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/utils/relative_date_utils.dart';

/// Shortcut to the wishes the user received, with the date of the latest one.
/// Shows nothing without a received wish, or when they cannot be loaded.
class HomeReceivedWishesRow extends ConsumerWidget {
  const HomeReceivedWishesRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final completedWishes =
        ref.watch(completedWishesRealtimeProvider).valueOrNull;

    if (completedWishes == null || completedWishes.isEmpty) {
      return const SizedBox.shrink();
    }

    final now = ref.watch(clockProvider)();
    final locale = Localizations.localeOf(context).toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Material(
        color: AppColors.gainsboro,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => CompletedWishesRoute().push(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.card_giftcard,
                  color: AppColors.primary,
                  size: 22,
                ),
                const Gap(12),
                Flexible(
                  child: Text(
                    l10n.homeReceivedWishes(completedWishes.length),
                    style: AppTextStyles.smaller.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Gap(8),
                Expanded(
                  child: Text(
                    // The repository sorts the last received first
                    formatRelativeDate(
                      l10n,
                      completedWishes.first.completedAt,
                      now: now,
                      locale: locale,
                    ),
                    style: AppTextStyles.smaller.copyWith(
                      color: AppColors.makara,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.makara),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
