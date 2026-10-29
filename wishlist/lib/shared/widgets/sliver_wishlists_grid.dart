import 'package:animated_reorderable_list/animated_reorderable_list.dart';
// `MotionListImpl` is the sliver behind `AnimatedReorderableGridView`, which is
// not exported. The grid widget wraps it in its own `CustomScrollView`, and the
// drag autoscroll scrolls the nearest `Scrollable`: inside a page that scrolls,
// that inner view would swallow the autoscroll and the page would stay still
// while a wishlist is dragged to the bottom. Using the sliver directly in the
// page's own `CustomScrollView` makes the page the one that scrolls.
// The one default that differs from the grid view is `longPressDraggable`
// (true there, false here): it is set explicitly below.
// Recheck this import on any upgrade of animated_reorderable_list (the
// dependency is pinned to 1.1.1 for that reason).
// ignore: implementation_imports
import 'package:animated_reorderable_list/src/builder/motion_list_impl.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/infra/wishlist_service.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/utils/app_snackbar.dart';
import 'package:wishlist/shared/widgets/wishlists_grid.dart';

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

    // With an optimistic order, check whether the stream data matches it
    if (_optimisticWishlists != null) {
      if (_isOrderMatching(widget.wishlists, _optimisticWishlists!)) {
        // The stream caught up with the optimistic order: drop it
        _optimisticWishlists = null;
      }
    }
  }

  bool _isOrderMatching(List<Wishlist> list1, List<Wishlist> list2) {
    if (list1.length != list2.length) {
      return false;
    }

    // Same order of ids
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

    final service = ref.read(wishlistServiceProvider);
    final errorMessage = context.l10n.genericError;
    try {
      await service.updateWishlistsOrder(reorderedWishlists.toIList());
    } catch (_) {
      if (!mounted) {
        return;
      }
      // The order was not saved: back to the one of the stream
      setState(() => _optimisticWishlists = null);
      showAppSnackBar(context, errorMessage, type: SnackBarType.error);
    }
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
        sliverGridDelegate: wishlistsGridDelegate,
        scrollDirection: Axis.vertical,
        // AnimatedReorderableGridView defaults to true, MotionListImpl to
        // false: without it a card lifts on touch and the page can't scroll.
        longPressDraggable: true,
        isSameItem: (a, b) => a.id == b.id,
        enterTransition: [
          FadeIn(
            curve: Curves.easeInOut,
            duration: wishlistsGridAnimationDuration,
          ),
          ScaleIn(
            curve: Curves.easeInOut,
            duration: wishlistsGridAnimationDuration,
          ),
        ],
        itemBuilder: (context, index) =>
            buildWishlistGridCard(_displayedWishlists[index], index),
      ),
    );
  }
}
