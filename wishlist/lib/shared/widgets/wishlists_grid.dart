import 'package:flutter/material.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/widgets/sliver_wishlists_grid.dart';

/// Grid of wishlists. Not reorderable, it is a sliver for a parent
/// `CustomScrollView`; reorderable, it is a scroll view of its own. A page that
/// needs the drag to scroll it uses [SliverWishlistsGrid] in its own
/// `CustomScrollView` instead.
class WishlistsGrid extends StatelessWidget {
  const WishlistsGrid({
    super.key,
    required this.wishlists,
    required this.isReorderable,
    this.padding,
  });

  final List<Wishlist> wishlists;
  final bool isReorderable;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    if (!isReorderable) {
      return buildPlainWishlistsSliver(wishlists);
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: padding ?? EdgeInsets.zero,
          sliver: SliverWishlistsGrid(wishlists: wishlists),
        ),
      ],
    );
  }
}
