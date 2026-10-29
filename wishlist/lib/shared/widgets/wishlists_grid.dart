import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/widgets/wishlist_card.dart';

const wishlistsGridAnimationDuration = Duration(milliseconds: 500);
const wishlistsGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
);

/// A wishlist card with its entrance animation, shared by the plain and the
/// reorderable grids.
Widget buildWishlistGridCard(Wishlist wishlist, int index) {
  return AnimationConfiguration.staggeredList(
    key: Key(wishlist.id.toString()),
    duration: wishlistsGridAnimationDuration,
    position: index,
    child: ScaleAnimation(
      child: FadeInAnimation(
        child: WishlistCard(
          wishlist: wishlist,
          color: AppColors.getColorFromHexValue(wishlist.color),
        ),
      ),
    ),
  );
}

/// Plain grid of wishlists, as a sliver for a parent `CustomScrollView`. A
/// page where the user reorders them uses `SliverWishlistsGrid` instead.
class WishlistsGrid extends StatelessWidget {
  const WishlistsGrid({super.key, required this.wishlists});

  final List<Wishlist> wishlists;

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: SliverGrid(
        gridDelegate: wishlistsGridDelegate,
        delegate: SliverChildBuilderDelegate(
          (context, index) => buildWishlistGridCard(wishlists[index], index),
          childCount: wishlists.length,
        ),
      ),
    );
  }
}
