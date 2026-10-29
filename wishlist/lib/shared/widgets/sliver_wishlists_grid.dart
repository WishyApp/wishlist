import 'package:animated_reorderable_list/animated_reorderable_list.dart';
// `MotionListImpl` is the sliver behind `AnimatedReorderableGridView`, which is
// not exported. The grid widget wraps it in its own `CustomScrollView`, and the
// drag autoscroll scrolls the nearest `Scrollable`: inside a page that scrolls,
// that inner view would swallow the autoscroll and the page would stay still
// while a wishlist is dragged to the bottom. Using the sliver directly in the
// page's own `CustomScrollView` makes the page the one that scrolls.
// Recheck this import on any upgrade of animated_reorderable_list (the
// dependency is pinned to 1.1.1 for that reason).
// ignore: implementation_imports
import 'package:animated_reorderable_list/src/builder/motion_list_impl.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:wishlist/shared/infra/wishlist_service.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/widgets/wishlist_card.dart';

const _animationDuration = Duration(milliseconds: 500);
const _sliverGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
);

/// A wishlist card with its entrance animation, shared by the plain and the
/// reorderable grids.
Widget buildWishlistGridCard(Wishlist wishlist, int index) {
  return AnimationConfiguration.staggeredList(
    key: Key(wishlist.id.toString()),
    duration: _animationDuration,
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

/// The same grid as [SliverGrid] with [buildWishlistGridCard], without
/// reordering.
Widget buildPlainWishlistsSliver(List<Wishlist> wishlists) {
  return AnimationLimiter(
    child: SliverGrid(
      gridDelegate: _sliverGridDelegate,
      delegate: SliverChildBuilderDelegate(
        (context, index) => buildWishlistGridCard(wishlists[index], index),
        childCount: wishlists.length,
      ),
    ),
  );
}

/// Reorderable grid of wishlists, as a sliver for a page's `CustomScrollView`.
/// A drag and drop saves the new order, which shows at once while the stream
/// catches up.
class SliverWishlistsGrid extends ConsumerStatefulWidget {
  const SliverWishlistsGrid({super.key, required this.wishlists});

  final List<Wishlist> wishlists;

  @override
  ConsumerState<SliverWishlistsGrid> createState() =>
      _SliverWishlistsGridState();
}

class _SliverWishlistsGridState extends ConsumerState<SliverWishlistsGrid> {
  List<Wishlist>? _optimisticWishlists;

  List<Wishlist> get _displayedWishlists =>
      _optimisticWishlists ?? widget.wishlists;

  @override
  void didUpdateWidget(SliverWishlistsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Si on a un état optimiste, on vérifie si les données du stream
    // correspondent
    if (_optimisticWishlists != null) {
      if (_isOrderMatching(widget.wishlists, _optimisticWishlists!)) {
        // Les données du stream correspondent à l'état optimiste, on peut le
        // réinitialiser
        _optimisticWishlists = null;
      }
    }
  }

  bool _isOrderMatching(List<Wishlist> list1, List<Wishlist> list2) {
    if (list1.length != list2.length) {
      return false;
    }

    // Vérifie que l'ordre des IDs est identique
    for (var i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id) {
        return false;
      }
    }

    return true;
  }

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    final reorderedWishlists = List<Wishlist>.from(_displayedWishlists);
    final wishlist = reorderedWishlists.removeAt(oldIndex);
    reorderedWishlists.insert(newIndex, wishlist);

    setState(() => _optimisticWishlists = reorderedWishlists);

    await ref
        .read(wishlistServiceProvider)
        .updateWishlistsOrder(reorderedWishlists.toIList());
  }

  Widget _buildProxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      ).drive(Tween(begin: 1, end: 1.2)),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: MotionListImpl<Wishlist>.grid(
        items: _displayedWishlists,
        onReorder: _handleReorder,
        proxyDecorator: _buildProxyDecorator,
        sliverGridDelegate: _sliverGridDelegate,
        scrollDirection: Axis.vertical,
        // AnimatedReorderableGridView defaults to true, MotionListImpl to
        // false: without it a card lifts on touch and the page can't scroll.
        longPressDraggable: true,
        isSameItem: (a, b) => a.id == b.id,
        enterTransition: [
          FadeIn(
            curve: Curves.easeInOut,
            duration: _animationDuration,
          ),
          ScaleIn(
            curve: Curves.easeInOut,
            duration: _animationDuration,
          ),
        ],
        itemBuilder: (context, index) =>
            buildWishlistGridCard(_displayedWishlists[index], index),
      ),
    );
  }
}
