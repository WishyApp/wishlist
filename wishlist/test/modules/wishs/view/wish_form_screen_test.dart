import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/wishs/view/wish_form_screen.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_streams_providers.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';
import '../../../pump_app.dart';

void main() {
  testWidgets('$WishFormScreen explains a wishlist load error and retries',
      (tester) async {
    final l10n = AppLocalizationsFr();
    var loads = 0;

    await tester.pumpPushedScreen(
      const WishFormScreen(wishlistId: 1),
      overrides: [
        supabaseClientOverride(),
        userServiceOverride(),
        // The theme is not cached, so it comes from the wishlist
        watchWishlistByIdProvider(1).overrideWith((ref) {
          loads++;
          return loads == 1
              ? Stream.error(
                  AppException(
                    statusCode: 500,
                    cause: const SocketException('Failed host lookup'),
                  ),
                )
              : Stream.value(fakeWishlist1);
        }),
      ],
    );

    expect(find.text(l10n.networkErrorTitle), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text(l10n.networkErrorTitle), findsNothing);
    expect(find.byType(TextFormField), findsWidgets);
  });
}
