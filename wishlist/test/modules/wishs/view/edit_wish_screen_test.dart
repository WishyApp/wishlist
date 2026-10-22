import 'dart:async';
import 'dart:io';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/wishs/view/screens/edit_wish_screen.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/repositories/wish/wish_streams_providers.dart';
import 'package:wishlist/shared/models/wish/wish.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';
import '../../../pump_app.dart';

void main() {
  testAdaptiveWidgets('$EditWishScreen golden test', (tester, variant) async {
    await tester.pumpApp(
      const EditWishScreen(wishId: 1),
      windowConfig: variant,
      overrides: wishScreenOverrides(
        wishId: 1,
        wishlistId: 1,
        wish: fakeWish1,
        wishlist: fakeWishlist1,
      ),
    );

    await tester.pumpAndSettle();

    await tester.expectGolden<EditWishScreen>(variant);
  });

  testWidgets('$EditWishScreen explains a load error and retries',
      (tester) async {
    final l10n = AppLocalizationsFr();
    var loads = 0;

    await tester.pumpPushedScreen(
      const EditWishScreen(wishId: 1),
      overrides: [
        supabaseClientOverride(),
        userServiceOverride(),
        watchWishlistByIdOverride(1, wishlist: fakeWishlist1),
        watchWishByIdProvider(1).overrideWith((ref) {
          loads++;
          return loads == 1
              ? Stream.error(
                  AppException(
                    statusCode: 500,
                    cause: const SocketException('Failed host lookup'),
                  ),
                )
              : Stream.value(fakeWish1);
        }),
      ],
    );

    expect(find.text(l10n.networkErrorTitle), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text(l10n.networkErrorTitle), findsNothing);
    expect(find.text(fakeWish1.name), findsOneWidget);
  });

  group('when the wish fails after being loaded', () {
    late StreamController<Wish> wishes;

    setUp(() => wishes = StreamController<Wish>());
    tearDown(() => wishes.close());

    Future<void> pumpLoadedForm(WidgetTester tester) async {
      await tester.pumpPushedScreen(
        const EditWishScreen(wishId: 1),
        overrides: [
          supabaseClientOverride(),
          userServiceOverride(),
          watchWishlistByIdOverride(1, wishlist: fakeWishlist1),
          watchWishByIdProvider(1).overrideWith((ref) => wishes.stream),
        ],
        settle: false,
      );
      wishes.add(fakeWish1);
      await tester.pumpAndSettle();
    }

    testWidgets('keeps the form, so that the edits are not lost',
        (tester) async {
      final l10n = AppLocalizationsFr();
      await pumpLoadedForm(tester);

      await tester.enterText(find.byType(TextFormField).first, 'My edit');
      wishes.addError(
        AppException(
          statusCode: 500,
          cause: const SocketException('Failed host lookup'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My edit'), findsOneWidget);
      expect(find.text(l10n.networkErrorTitle), findsNothing);
    });

    testWidgets('says that the wish is unavailable once it is gone',
        (tester) async {
      final l10n = AppLocalizationsFr();
      await pumpLoadedForm(tester);

      wishes.addError(
        AppException(
          statusCode: 500,
          cause: const PostgrestException(
            message: 'no rows',
            code: 'PGRST116',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.wishUnavailable), findsOneWidget);
    });
  });
}
