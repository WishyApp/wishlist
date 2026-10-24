import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/booked_wishes/view/widgets/booked_wishes_search_bar.dart';
import 'package:wishlist/modules/booked_wishes/view/widgets/booked_wishes_stats.dart';
import 'package:wishlist/modules/booked_wishes/view/widgets/booked_wishes_tab_switch.dart';
import 'package:wishlist/modules/booked_wishes/view/widgets/user_group_header.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wish_card.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_stats_card.dart';
import 'package:wishlist/modules/wishs/view/screens/consult_wish_screen.dart';
import 'package:wishlist/shared/infra/booked_wishes_realtime_provider.dart';
import 'package:wishlist/shared/models/booked_wish_sort_type.dart';
import 'package:wishlist/shared/models/booked_wish_with_details/booked_wish_with_details.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/page_layout_empty/page_layout_empty.dart';
import 'package:wishlist/shared/page_layout_error/page_layout_error.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/theme/widgets/app_scaffold.dart';
import 'package:wishlist/shared/utils/booked_wish_sort_utils.dart';
import 'package:wishlist/shared/utils/retry_providers_extension.dart';
import 'package:wishlist/shared/utils/string_utils.dart';
import 'package:wishlist/shared/widgets/animated_list_view.dart';
import 'package:wishlist/shared/widgets/measure_size.dart';
import 'package:wishlist/shared/widgets/page_layout.dart';

class BookedWishesScreen extends ConsumerStatefulWidget {
  const BookedWishesScreen({super.key});

  @override
  ConsumerState<BookedWishesScreen> createState() => _BookedWishesScreenState();
}

class _BookedWishesScreenState extends ConsumerState<BookedWishesScreen> {
  static const double _contentPadding = 16;
  static const double _itemSpacing = 16;
  static const EdgeInsets _headerPadding =
      EdgeInsets.fromLTRB(_contentPadding, _contentPadding, _contentPadding, 8);
  static const int _estimatedMaxItems = 10;

  /// Height of the fixed header (stats, search bar and tabs) the list
  /// scrolls under: measured, since it grows with the text scale. Until the
  /// first measure, its height with the default text scale.
  double _headerHeight = 188;

  BookedWishesTab _tab = BookedWishesTab.toGive;

  BookedWishSort _sort = const BookedWishSort(
    type: BookedWishSortType.alphabetical,
    order: SortOrder.ascending,
  );

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = normalizeString(_searchController.text);
    });
  }

  void _onSortChanged(BookedWishSort sort) {
    setState(() {
      _sort = sort;
    });
  }

  void _clearFocus() {
    FocusScope.of(context).requestFocus(FocusNode());
  }

  Future<void> _refreshBookedWishes() async {
    ref.invalidate(bookedWishesRealtimeProvider);
  }

  /// Filtre et groupe les wishes par utilisateur
  Map<String, List<BookedWishWithDetails>> _filterAndGroupWishes(
    List<BookedWishWithDetails> bookedWishes,
  ) {
    return BookedWishSortUtils.filterAndGroupWishes(
      bookedWishes,
      sort: _sort,
      searchQuery: _searchQuery,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bookedWishesAsync = ref.watch(bookedWishesRealtimeProvider);

    return bookedWishesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => PageLayoutError(
        error: error,
        onRetry: () => ref.retryFailed([bookedWishesRealtimeProvider]),
        isRetrying: ref.isRetryingAny([bookedWishesRealtimeProvider]),
        appBarTitle: l10n.bookedWishesScreenTitle,
      ),
      data: (bookedWishes) {
        if (bookedWishes.isEmpty) {
          return _buildEmptyState(l10n);
        }

        final toGive = <BookedWishWithDetails>[];
        final given = <BookedWishWithDetails>[];
        for (final bookedWish in bookedWishes) {
          (bookedWish.isGiven ? given : toGive).add(bookedWish);
        }
        final tabWishes = _tab == BookedWishesTab.toGive ? toGive : given;

        final header = _buildHeader(
          l10n,
          tabWishes: tabWishes,
          toGiveCount: toGive.length,
          givenCount: given.length,
        );
        final groupedWishes = _filterAndGroupWishes(tabWishes);

        return PageLayout(
          title: l10n.bookedWishesScreenTitle,
          onRefresh: _refreshBookedWishes,
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
              Positioned.fill(
                child: groupedWishes.isEmpty
                    ? _buildEmptyTabMessage(l10n)
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _contentPadding,
                        ),
                        child: _buildAnimatedListView(groupedWishes),
                      ),
              ),
              // Header fixe avec stats + searchbar + onglets
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: MeasureSize(
                  onChange: (size) {
                    if (mounted && size.height != _headerHeight) {
                      setState(() => _headerHeight = size.height);
                    }
                  },
                  child: header,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return PageLayoutEmpty(
      illustrationUrl: Assets.svg.noBookedWish,
      title: l10n.bookedWishesEmptyTitle,
      onRefresh: _refreshBookedWishes,
      appBarTitle: l10n.bookedWishesScreenTitle,
    );
  }

  /// Nothing to show in the current tab: no search result, or a tab empty
  /// on its own
  Widget _buildEmptyTabMessage(AppLocalizations l10n) {
    final message = _searchQuery.isNotEmpty
        ? l10n.wishlistNoWishBooked
        : switch (_tab) {
            BookedWishesTab.toGive => l10n.bookedWishesNothingToGive,
            BookedWishesTab.given => l10n.bookedWishesNothingGiven,
          };

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _contentPadding * 2,
        _headerHeight,
        _contentPadding * 2,
        0,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.small.copyWith(color: AppColors.makara),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    AppLocalizations l10n, {
    required List<BookedWishWithDetails> tabWishes,
    required int toGiveCount,
    required int givenCount,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background,
            AppColors.background,
            AppColors.background.withValues(alpha: 0.95),
            AppColors.background.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.7, 0.9, 1.0],
        ),
      ),
      child: Padding(
        padding: _headerPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: _itemSpacing,
          children: [
            BookedWishesStats(
              bookedWishes: tabWishes,
              countLabel: _countLabel(l10n, tabWishes.length),
            ),
            BookedWishesSearchBar(
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              searchQuery: _searchQuery,
              sort: _sort,
              onSortChanged: _onSortChanged,
              onClearFocus: _clearFocus,
              footer: BookedWishesTabSwitch(
                current: _tab,
                toGiveCount: toGiveCount,
                givenCount: givenCount,
                onChanged: (tab) => setState(() => _tab = tab),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _countLabel(AppLocalizations l10n, int count) {
    return switch (_tab) {
      BookedWishesTab.toGive => l10n.bookedWishesToGiveCount(count),
      BookedWishesTab.given => l10n.bookedWishesGivenCount(count),
    };
  }

  Widget _buildAnimatedListView(
    Map<String, List<BookedWishWithDetails>> groupedWishes,
  ) {
    // Convertir la Map en List pour AnimatedListView
    final groupsList =
        groupedWishes.entries.map((entry) => entry.value).toList();

    return AnimatedListView<List<BookedWishWithDetails>>(
      // One list per tab: switching starts from the top, without animating
      // the groups of one tab into the other's
      key: ValueKey(_tab),
      items: groupsList,
      padding: EdgeInsets.only(
        top: _headerHeight,
        bottom: NavBarPadding.of(context),
      ),
      itemSpacing: _itemSpacing,
      estimatedMaxItems: _estimatedMaxItems,
      verticalOffset: 50,
      separatorBuilder: (context, index) => const Gap(_itemSpacing),
      itemEquality: (oldItem, newItem) {
        // Comparer par l'ID du propriétaire (premier wish du groupe)
        return oldItem.isNotEmpty &&
            newItem.isNotEmpty &&
            oldItem.first.ownerId == newItem.first.ownerId;
      },
      itemBuilder: (context, ownerWishes, index) {
        if (ownerWishes.isEmpty) {
          return const SizedBox.shrink();
        }
        final firstWish = ownerWishes.first;
        return _buildUserGroupCard(ownerWishes, firstWish);
      },
    );
  }

  Widget _buildUserGroupCard(
    List<BookedWishWithDetails> ownerWishes,
    BookedWishWithDetails firstWish,
  ) {
    return Container(
      padding: const EdgeInsets.all(_contentPadding),
      decoration: BoxDecoration(
        color: AppColors.gainsboro,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserGroupHeader(
            avatarUrl: firstWish.ownerAvatarUrl,
            pseudo: firstWish.ownerPseudo,
            countLabel: _countLabel(context.l10n, ownerWishes.length),
            onTap: () => _onUserTap(firstWish.ownerId),
          ),
          const Gap(_itemSpacing),
          Column(
            spacing: 8,
            children: ownerWishes.map((bookedWish) {
              return WishCard(
                wish: bookedWish.wish,
                onTap: () => _onWishTap(bookedWish),
                onFavoriteToggle: () {}, // Non-cliquable pour booked wishes
                isMyWishlist: false,
                cardType: WishlistStatsCardType.booked,
                subtitle: _subtitle(bookedWish),
                quantityOverride: bookedWish.bookedQuantity,
                showAvatars: false,
                showReceivedBadge: bookedWish.isGiven,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// The wishlist of the wish, or when its owner received it once given
  String _subtitle(BookedWishWithDetails bookedWish) {
    final receivedAt = bookedWish.receivedAt;
    if (!bookedWish.isGiven || receivedAt == null) {
      return bookedWish.wishlistName;
    }
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(receivedAt.toLocal());
    return context.l10n.bookedWishReceivedOn(date);
  }

  void _onWishTap(BookedWishWithDetails bookedWish) {
    ConsultWishRoute(
      bookedWish.wish.wishlistId,
      bookedWish.wish.id,
      wishIds: [bookedWish.wish.id],
      quantityDisplay: WishQuantityDisplay.myBooked,
    ).push(context);
  }

  void _onUserTap(String userId) {
    FriendDetailsRoute(userId).push(context);
  }
}
