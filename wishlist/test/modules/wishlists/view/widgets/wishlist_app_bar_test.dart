import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_app_bar.dart';
import 'package:wishlist/shared/widgets/share_icon_button.dart';

import '../../../../pump_app.dart';

void main() {
  Widget appBar({required bool canShare}) => Scaffold(
        appBar: WishlistAppBar(
          title: 'Noël',
          wishlistTheme: ThemeData(),
          isMyWishlist: true,
          canShareWishlist: canShare,
          shareParams: () => ShareParams(text: 'Noël'),
          onShareError: (_) {},
          onSettings: () {},
        ),
      );

  testWidgets('shows the share button when the wishlist can be shared', (
    tester,
  ) async {
    await tester.pumpApp(appBar(canShare: true));
    expect(find.byType(ShareIconButton), findsOneWidget);
  });

  testWidgets('hides the share button otherwise', (tester) async {
    await tester.pumpApp(appBar(canShare: false));
    expect(find.byType(ShareIconButton), findsNothing);
  });
}
