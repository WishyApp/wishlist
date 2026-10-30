import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/home/cards/home_card_candidate.dart';
import 'package:wishlist/modules/home/cards/year_recap_provider.dart';
import 'package:wishlist/shared/infra/booked_wishes_realtime_provider.dart';
import 'package:wishlist/shared/page_layout_error/page_layout_error.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';
import 'package:wishlist/shared/utils/retry_providers_extension.dart';
import 'package:wishlist/shared/widgets/page_layout.dart';

/// The page behind the card "Ton année Wishy". It works out its facts again
/// (`yearRecapFactsProvider`): nothing is handed over by the route.
class YearRecapScreen extends ConsumerWidget {
  const YearRecapScreen({super.key, required this.year});

  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final facts = ref.watch(yearRecapFactsProvider(year));

    return facts.when(
      loading: () => PageLayout(
        title: l10n.yearRecapScreenTitle('$year'),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => PageLayoutError(
        error: error,
        appBarTitle: l10n.yearRecapScreenTitle('$year'),
        onRetry: () async {
          // The bookings feed the recap too: a failed stream keeps serving its
          // error until it is reopened. Failing again shows in the page, it
          // must not escape here.
          await ref.retryFailed([bookedWishesRealtimeProvider]).then(
            (_) {},
            onError: (_) {},
          );
          ref.invalidate(receivedWishesSnapshotProvider);
          await ref.refresh(yearRecapFactsProvider(year).future).then(
                (_) {},
                onError: (_) {},
              );
        },
      ),
      data: (facts) => _Recap(facts: facts),
    );
  }
}

class _Recap extends StatelessWidget {
  const _Recap({required this.facts});

  final YearRecapFacts facts;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final awaited = facts.longestAwaited;
    final friend = facts.mostGiftedFriendPseudo;

    return PageLayout.scrolling(
      title: l10n.yearRecapScreenTitle('${facts.year}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SvgPicture.asset(
              Assets.svg.noWishBoxHat,
              width: 160,
              height: 160,
            ),
          ),
          const Gap(16),
          _Block(text: l10n.yearRecapReceived(facts.receivedCount)),
          const Gap(12),
          _Block(text: l10n.yearRecapOffered(facts.offeredCount)),
          if (awaited != null) ...[
            const Gap(12),
            _Block(
              text: l10n.yearRecapLongestAwaited(
                awaited.wish.name,
                DateFormat.yMMMMd(locale)
                    .format(awaited.wish.createdAt.toLocal()),
              ),
            ),
          ],
          if (friend != null) ...[
            const Gap(12),
            _Block(text: l10n.yearRecapMostGifted(friend)),
          ],
          const Gap(24),
          PrimaryButton(
            text: l10n.yearRecapBack,
            onPressed: () => context.pop(),
            style: BaseButtonStyle.large,
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.gainsboro,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
