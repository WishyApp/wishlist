import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_selection_card.dart';

import '../../../../pump_app.dart';

void main() {
  final l10n = AppLocalizationsFr();

  Future<void> pumpCard(
    WidgetTester tester, {
    double width = 343,
    double height = 90,
    bool areAllSelected = false,
    VoidCallback? onToggleSelectAll,
    VoidCallback? onExit,
  }) {
    return tester.pumpApp(
      Center(
        child: SizedBox(
          width: width,
          height: height,
          child: WishlistSelectionCard(
            selectedCount: 12,
            areAllSelected: areAllSelected,
            onToggleSelectAll: onToggleSelectAll,
            onExit: onExit ?? () {},
          ),
        ),
      ),
    );
  }

  Finder button(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byType(TextButton),
      );

  testWidgets('toggles between select all and deselect all', (tester) async {
    var toggles = 0;
    await pumpCard(tester, onToggleSelectAll: () => toggles++);

    await tester.tap(find.text(l10n.wishlistSelectAll));
    expect(toggles, 1);

    await pumpCard(tester, areAllSelected: true, onToggleSelectAll: () {});
    expect(find.text(l10n.wishlistDeselectAll), findsOneWidget);
  });

  testWidgets('disables select all when no wish is displayed', (tester) async {
    await pumpCard(tester);

    expect(
      tester.widget<TextButton>(button(l10n.wishlistSelectAll)).enabled,
      isFalse,
    );
  });

  testWidgets('keeps 48dp buttons on a narrow screen with a large text',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    // The card on a 320dp wide screen, as high as the stats cards at this
    // scale. An overflow would fail the test.
    await pumpCard(
      tester,
      width: 288,
      height: 130,
      onToggleSelectAll: () {},
    );

    for (final target in [
      button(l10n.wishlistSelectAll),
      find.byTooltip(l10n.wishlistExitSelection),
    ]) {
      final size = tester.getSize(target);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });
}
