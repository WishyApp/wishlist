import 'dart:async';

import 'package:adaptive_test/adaptive_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_settings_app_bar.dart';
import 'package:wishlist/modules/wishlists/view/wishlist_settings_screen.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_streams_providers.dart';
import 'package:wishlist/shared/infra/wishlist_service.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';
import 'package:wishlist/shared/widgets/app_switch.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';
import '../../../pump_app.dart';

class _MockWishlistService extends Mock implements WishlistService {}

class _FakeWishlist extends Fake implements Wishlist {}

const _homeText = 'home';
const _wishlistText = 'wishlist';

/// The settings screen pushed above stand-ins of the home and wishlist
/// screens, to see where it leads back.
List<RouteBase> _routes(int wishlistId) => [
      GoRoute(
        path: '/',
        builder: (_, __) => const Text(_homeText),
        routes: [
          GoRoute(
            path: 'wishlist/$wishlistId',
            builder: (_, __) => const Text(_wishlistText),
            routes: [
              GoRoute(
                path: 'settings',
                builder: (_, __) =>
                    WishlistSettingsScreen(wishlistId: wishlistId),
              ),
            ],
          ),
        ],
      ),
    ];

void main() {
  final l10n = AppLocalizationsFr();
  final wishlist = fakeWishlist2;
  late _MockWishlistService service;

  setUpAll(() => registerFallbackValue(_FakeWishlist()));

  setUp(() {
    service = _MockWishlistService();
    when(() => service.updateWishlist(any()))
        .thenAnswer((invocation) async => invocation.positionalArguments.first);
    when(() => service.deleteWishlist(any())).thenAnswer((_) async {});
  });

  List<Override> overrides({Stream<Wishlist?>? wishlists}) => [
        supabaseClientOverride(userId: fakeCurrentUserId),
        watchWishlistByIdProvider(wishlist.id).overrideWith(
          (ref) => wishlists ?? Stream.value(wishlist),
        ),
        wishlistServiceProvider.overrideWithValue(service),
      ];

  Future<void> pumpScreen(
    WidgetTester tester, {
    WindowConfigData? windowConfig,
    StreamController<Wishlist?>? wishlists,
  }) async {
    await tester.pumpRouterApp(
      '/wishlist/${wishlist.id}/settings',
      windowConfig: windowConfig,
      routes: _routes(wishlist.id),
      overrides: overrides(wishlists: wishlists?.stream),
    );
    // A spinner shows until the first wishlist: pumpAndSettle would not end
    wishlists?.add(wishlist);
    await tester.pumpAndSettle();
  }

  Finder nameField() => find.byType(TextFormField);

  // The only PrimaryButton of the screen. A button text is found twice: it is
  // also laid out invisible, to keep the height of the button while loading
  Finder saveButton() => find.byType(PrimaryButton);

  bool isSaveEnabled(WidgetTester tester) =>
      tester.widget<PrimaryButton>(saveButton()).onPressed != null;

  /// Lets the success snackbar go away, so that no timer is left pending.
  Future<void> dismissSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testAdaptiveWidgets('$WishlistSettingsScreen golden test',
      (tester, variant) async {
    await pumpScreen(tester, windowConfig: variant);

    await tester.expectGolden<WishlistSettingsScreen>(variant);
  });

  testWidgets('enables saving only once a setting changes', (tester) async {
    await pumpScreen(tester);

    expect(isSaveEnabled(tester), isFalse);

    await tester.tap(find.text(l10n.private));
    await tester.pump();
    expect(isSaveEnabled(tester), isTrue);

    await tester.tap(find.text(l10n.public));
    await tester.pump();
    expect(isSaveEnabled(tester), isFalse);
  });

  testWidgets('shows the name being typed in the app bar', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(nameField(), 'Noël 2026');
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(WishlistSettingsAppBar),
        matching: find.text('Noël 2026'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('refuses a blank name and says why', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(nameField(), '   ');
    await tester.pump();

    // Also in the field, invisible: the field only turns red
    expect(find.text(l10n.wishlistNameRequired), findsWidgets);
    expect(isSaveEnabled(tester), isFalse);
  });

  testWidgets('saves the trimmed name and the settings, then goes back',
      (tester) async {
    await pumpScreen(tester);

    await tester.enterText(nameField(), '  Noël 2026  ');
    await tester.tap(find.bySemanticsLabel(l10n.colorPurple));
    await tester.tap(find.text(l10n.private));
    await tester.tap(find.byType(AppSwitch));
    await tester.pump();
    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    final saved = verify(() => service.updateWishlist(captureAny()))
        .captured
        .single as Wishlist;
    expect(saved.id, wishlist.id);
    expect(saved.name, 'Noël 2026');
    expect(
      AppColors.getColorFromHexValue(saved.color),
      AppColors.purple,
    );
    expect(saved.visibility, WishlistVisibility.private);
    expect(saved.canOwnerSeeTakenWish, isTrue);
    expect(find.text(_wishlistText), findsOneWidget);

    await dismissSnackBar(tester);
  });

  testWidgets('goes back right away when nothing changed', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text(_wishlistText), findsOneWidget);
  });

  group('going back with unsaved changes', () {
    Future<void> changeThenGoBack(WidgetTester tester) async {
      await pumpScreen(tester);
      await tester.enterText(nameField(), 'Noël 2026');
      await tester.pump();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }

    testWidgets('asks first, and stays to keep editing', (tester) async {
      await changeThenGoBack(tester);

      expect(find.text(l10n.unsavedChangesTitle), findsOneWidget);

      await tester.tap(find.text(l10n.unsavedChangesKeepEditing).first);
      await tester.pumpAndSettle();

      expect(find.text(l10n.unsavedChangesTitle), findsNothing);
      expect(find.text('Noël 2026'), findsWidgets);
      expect(find.text(_wishlistText), findsNothing);
    });

    testWidgets('leaves without saving once confirmed', (tester) async {
      await changeThenGoBack(tester);

      await tester.tap(find.text(l10n.unsavedChangesLeave).first);
      await tester.pumpAndSettle();

      expect(find.text(_wishlistText), findsOneWidget);
      verifyNever(() => service.updateWishlist(any()));
    });
  });

  testWidgets('deletes the wishlist once confirmed, then goes home',
      (tester) async {
    // The stream says the wishlist is gone as soon as it is deleted
    final wishlists = StreamController<Wishlist?>();
    addTearDown(wishlists.close);
    when(() => service.deleteWishlist(any())).thenAnswer((_) async {
      wishlists.add(null);
      await Future<void>.delayed(Duration.zero);
    });
    await pumpScreen(tester, wishlists: wishlists);

    await tester.ensureVisible(find.text(l10n.deleteWishlist));
    await tester.tap(find.text(l10n.deleteWishlist));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.deleteButton).first);
    await tester.pumpAndSettle();

    verify(() => service.deleteWishlist(wishlist.id)).called(1);
    expect(find.text(_homeText), findsOneWidget);
    expect(find.text(l10n.wishlistDeleted), findsNothing);

    await dismissSnackBar(tester);
  });

  testWidgets('says that the wishlist is gone when deleted elsewhere',
      (tester) async {
    final wishlists = StreamController<Wishlist?>();
    addTearDown(wishlists.close);
    await pumpScreen(tester, wishlists: wishlists);

    wishlists.add(null);
    await tester.pumpAndSettle();

    expect(find.text(l10n.wishlistDeleted), findsOneWidget);
  });

  testWidgets('keeps the edits when the wishlist changes elsewhere',
      (tester) async {
    final wishlists = StreamController<Wishlist?>();
    addTearDown(wishlists.close);
    await pumpScreen(tester, wishlists: wishlists);

    await tester.enterText(nameField(), 'Noël 2026');
    wishlists.add(
      wishlist.copyWith(
        name: 'Renamed elsewhere',
        visibility: WishlistVisibility.private,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextFormField>(nameField()).controller?.text,
      'Noël 2026',
    );
    expect(find.text(l10n.wishlistPrivateDescription), findsOneWidget);
  });
  testWidgets('is only open to the owner of the wishlist', (tester) async {
    // A public wishlist of another user, reached by a deep link
    final othersWishlist = Wishlist(
      id: wishlist.id,
      createdAt: wishlist.createdAt,
      name: wishlist.name,
      idOwner: fakePendingUserId,
      color: wishlist.color,
      visibility: WishlistVisibility.public,
      order: 0,
      updatedBy: fakePendingUserId,
      updatedAt: wishlist.updatedAt,
    );
    await tester.pumpRouterApp(
      '/wishlist/${wishlist.id}/settings',
      routes: _routes(wishlist.id),
      overrides: overrides(wishlists: Stream.value(othersWishlist)),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.wishlistSettingsOwnerOnly), findsOneWidget);
    expect(find.byType(AppSwitch), findsNothing);
  });

  testWidgets('freezes the page while saving, so that no edit is lost',
      (tester) async {
    final saving = Completer<Wishlist>();
    when(() => service.updateWishlist(any())).thenAnswer((_) => saving.future);
    await pumpScreen(tester);

    await tester.tap(find.text(l10n.private));
    await tester.pump();
    await tester.tap(saveButton());
    await tester.pump();

    // Too late for this save: ignored rather than lost when the page closes
    await tester.tap(find.byType(AppSwitch));
    await tester.pump();
    expect(find.text(l10n.seeBookedWishesOffDescription), findsOneWidget);

    saving.complete(wishlist);
    await tester.pumpAndSettle();

    final saved = verify(() => service.updateWishlist(captureAny()))
        .captured
        .single as Wishlist;
    expect(saved.visibility, WishlistVisibility.private);
    expect(saved.canOwnerSeeTakenWish, isFalse);
    expect(find.text(_wishlistText), findsOneWidget);

    await dismissSnackBar(tester);
  });

  testWidgets('fits a narrow screen with a large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpScreen(tester);

    // An overflow would have failed the test. Next to the swatches, the
    // color title would also have broken over several lines
    expect(
      tester.getSize(find.text(l10n.wishlistColorLabel)).height,
      tester.getSize(find.text(l10n.wishlistVisibilityLabel)).height,
    );
  });
}
