import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/wishlists/view/widgets/move_wishes_dialog.dart';
import 'package:wishlist/shared/infra/wishlists_realtime_provider.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';

import '../../../../fixtures/fake_data.dart';
import '../../../../pump_app.dart';

void main() {
  final l10n = AppLocalizationsFr();

  testWidgets('preselects the most recent other wishlist once', (tester) async {
    Wishlist wishlist(int id, String name, DateTime createdAt) => Wishlist(
          id: id,
          createdAt: createdAt,
          name: name,
          idOwner: fakeCurrentUserId,
          color: fakeColorBlue,
          canOwnerSeeTakenWish: true,
          order: 0,
          updatedBy: fakeCurrentUserId,
          updatedAt: fakeUpdatedAt,
        );
    final older = wishlist(2, 'Older', DateTime(2024));
    final newer = wishlist(3, 'Newer', DateTime(2025));
    final current = wishlist(1, 'Current', DateTime(2026));
    final controller = StreamController<List<Wishlist>>();
    addTearDown(controller.close);
    int? moved;

    await tester.pumpApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showMoveWishesDialog(
            context,
            currentWishlistId: 1,
            wishCount: 1,
            onConfirm: (id) async => moved = id,
          ),
          child: const Text('open'),
        ),
      ),
      overrides: [
        wishlistsRealtimeProvider.overrideWith((ref) => controller.stream),
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    controller.add([older, newer, current]);
    await tester.pumpAndSettle();

    // The current wishlist is excluded even though it is the most recent
    expect(find.text('Newer'), findsOneWidget);
    expect(find.text('Older'), findsNothing);

    // A later emission does not override the selection
    controller.add([older, newer, current]);
    await tester.pumpAndSettle();
    expect(find.text('Newer'), findsOneWidget);

    await tester.tap(find.text(l10n.moveButton).last);
    await tester.pumpAndSettle();
    expect(moved, 3);
  });
}
