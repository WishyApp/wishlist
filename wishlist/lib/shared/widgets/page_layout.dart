import 'package:flutter/material.dart';
import 'package:wishlist/shared/theme/widgets/app_app_bar.dart';
import 'package:wishlist/shared/theme/widgets/app_refresh_indicator.dart';

class PageLayout extends StatelessWidget {
  const PageLayout({
    super.key,
    required this.title,
    required this.child,
    this.onRefresh,
    this.padding = const EdgeInsets.all(20),
    this.actions,
  }) : _isScrollingContent = false;

  /// A page whose [child] scrolls and handles the bottom itself: no bottom
  /// padding, the content scrolls under the home indicator and its
  /// `SliverSafeArea` keeps the last item clear of it, so the bottom inset is
  /// not stacked on a fixed margin. The minimum is for devices without an
  /// inset.
  const PageLayout.scrolling({
    super.key,
    required this.title,
    required this.child,
  })  : onRefresh = null,
        padding = const EdgeInsets.fromLTRB(20, 20, 20, 0),
        actions = null,
        _isScrollingContent = true;

  final String title;
  final Widget child;
  final Future<void> Function()? onRefresh;
  final EdgeInsets padding;
  final List<Widget>? actions;
  final bool _isScrollingContent;

  @override
  Widget build(BuildContext context) {
    final onRefresh = this.onRefresh;

    final content = _isScrollingContent
        ? SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverSafeArea(
                  top: false,
                  left: false,
                  right: false,
                  minimum: const EdgeInsets.only(bottom: 16),
                  sliver: SliverToBoxAdapter(child: child),
                ),
              ],
            ),
          )
        : child;

    return Scaffold(
      appBar: AppAppBar(
        title: title,
      ),
      body: Padding(
        padding: padding,
        child: onRefresh != null
            ? AppRefreshIndicator(
                onRefresh: onRefresh,
                child: content,
              )
            : content,
      ),
    );
  }
}
