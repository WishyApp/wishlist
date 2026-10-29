import 'package:flutter/material.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/widgets/sliver_wishlists_grid.dart';

/// Plain grid of wishlists, as a sliver for a parent `CustomScrollView`. A
/// page where the user reorders them uses `SliverWishlistsGrid` instead.
class WishlistsGrid extends StatelessWidget {
  const WishlistsGrid({super.key, required this.wishlists});

  final List<Wishlist> wishlists;

  @override
  Widget build(BuildContext context) {
    return buildPlainWishlistsSliver(wishlists);
  }
}
