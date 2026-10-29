import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_app_bar.dart';

import '../../../../pump_app.dart';

void main() {
  testWidgets('share passes the area of the button (iPad share sheet)', (
    tester,
  ) async {
    Rect? origin;
    await tester.pumpApp(
      Scaffold(
        appBar: WishlistAppBar(
          title: 'Noël',
          wishlistTheme: ThemeData(),
          isMyWishlist: true,
          canShareWishlist: true,
          onShare: (rect) => origin = rect,
          onSettings: () {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.share));

    final button = find.ancestor(
      of: find.byIcon(Icons.share),
      matching: find.byType(IconButton),
    );
    expect(origin, tester.getRect(button));
    expect(origin!.isEmpty, isFalse);
  });
}
