import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/home/cards/year_recap_provider.dart';
import 'package:wishlist/modules/year_recap/most_gifted_friend.dart';
import 'package:wishlist/modules/year_recap/share/year_recap_sharer.dart';
import 'package:wishlist/modules/year_recap/year_recap_texts.dart';
import 'package:wishlist/shared/infra/booked_wishes_realtime_provider.dart';
import 'package:wishlist/shared/infra/repositories/year_recap/year_recap_repository_provider.dart';
import 'package:wishlist/shared/models/year_recap/year_recap.dart';
import 'package:wishlist/shared/page_layout_error/page_layout_error.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';
import 'package:wishlist/shared/utils/app_snackbar.dart';
import 'package:wishlist/shared/widgets/page_layout.dart';

/// The page behind the card "Ton année Wishy". It loads its recap again
/// (`yearRecapFactsProvider`): nothing is handed over by the route.
class YearRecapScreen extends ConsumerWidget {
  const YearRecapScreen({super.key, required this.year});

  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final recap = ref.watch(yearRecapFactsProvider(year));

    return recap.when(
      loading: () => PageLayout(
        title: l10n.yearRecapScreenTitle('$year'),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => PageLayoutError(
        error: error,
        appBarTitle: l10n.yearRecapScreenTitle('$year'),
        onRetry: () async {
          // The failure shows again in the page, it must not escape here
          await ref.refresh(yearRecapFactsProvider(year).future).then(
                (_) {},
                onError: (_) {},
              );
        },
      ),
      data: (recap) => _Recap(recap: recap),
    );
  }
}

class _Recap extends ConsumerStatefulWidget {
  const _Recap({required this.recap});

  final YearRecapData recap;

  @override
  ConsumerState<_Recap> createState() => _RecapState();
}

class _RecapState extends ConsumerState<_Recap> {
  bool _isSharing = false;

  Future<void> _share() async {
    if (_isSharing) {
      return;
    }
    setState(() => _isSharing = true);
    try {
      await ref.read(yearRecapSharerProvider).share(context, widget.recap);
    } catch (e) {
      if (mounted) {
        showGenericError(context, error: e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final recap = widget.recap;
    final stats = recap.stats;
    final awaited = stats.longestAwaited;
    // The server returns no pseudo: the bookings the app already has give it
    final bookings = ref.watch(bookedWishesRealtimeProvider).valueOrNull;
    final friend = bookings == null
        ? null
        : mostGiftedFriendPseudo(
            bookings: bookings.toList(),
            year: recap.year,
          );

    return PageLayout.scrolling(
      title: l10n.yearRecapScreenTitle('${recap.year}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfileBlock(recap: recap),
          const Gap(24),
          _Block(text: l10n.yearRecapReceived(stats.received)),
          const Gap(12),
          _Block(text: l10n.yearRecapOffered(stats.offered)),
          if (awaited != null) ...[
            const Gap(12),
            _Block(
              text: l10n.yearRecapLongestAwaited(
                awaited.wishName,
                DateFormat.yMMMMd(locale).format(awaited.createdOn),
              ),
            ),
          ],
          if (friend != null) ...[
            const Gap(12),
            _Block(text: l10n.yearRecapMostGifted(friend)),
          ],
          const Gap(24),
          PrimaryButton(
            text: l10n.yearRecapShareButton,
            onPressed: _isSharing ? null : _share,
            isLoading: _isSharing,
            style: BaseButtonStyle.large,
          ),
          const Gap(12),
          SecondaryButton(
            text: l10n.yearRecapBack,
            onPressed: () => context.pop(),
            style: BaseButtonStyle.large,
          ),
        ],
      ),
    );
  }
}

/// "Cette année, j'étais" and the profile: title, illustration, tagline and
/// the figures behind it.
class _ProfileBlock extends ConsumerWidget {
  const _ProfileBlock({required this.recap});

  final YearRecapData recap;

  static const _illustrationHeight = 200.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final key = recap.profile.key;
    final path = recap.profile.illustrationPath;
    final url = path == null
        ? null
        : ref.watch(yearRecapRepositoryProvider).illustrationUrl(path);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.yearRecapProfileIntro,
          textAlign: TextAlign.center,
          style: AppTextStyles.small.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.makara,
          ),
        ),
        const Gap(4),
        Text(
          l10n.yearRecapProfileTitle(key),
          textAlign: TextAlign.center,
          style: AppTextStyles.title,
        ),
        const Gap(16),
        SizedBox(
          height: _illustrationHeight,
          child: url == null
              ? const _GenericIllustration()
              : Image(
                  image: CachedNetworkImageProvider(url),
                  fit: BoxFit.contain,
                  // Nothing while it loads, the generic one if it fails
                  frameBuilder: (_, child, frame, wasSynchronouslyLoaded) =>
                      wasSynchronouslyLoaded || frame != null
                          ? child
                          : const SizedBox.shrink(),
                  errorBuilder: (_, __, ___) => const _GenericIllustration(),
                ),
        ),
        const Gap(16),
        Text(
          l10n.yearRecapProfileTagline(key),
          textAlign: TextAlign.center,
          style: AppTextStyles.medium.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.darkOrange,
          ),
        ),
        const Gap(12),
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                l10n.yearRecapProfileStat(recap),
                textAlign: TextAlign.center,
                style: AppTextStyles.smaller.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkGrey,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GenericIllustration extends StatelessWidget {
  const _GenericIllustration();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(Assets.svg.noWishBoxHat);
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
