import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/theme/widgets/app_scaffold.dart';

void main() {
  const screenSize = Size(400, 800);
  const navBarKey = Key('nav-bar');

  Future<void> pumpAppScaffold(
    WidgetTester tester, {
    required double keyboardHeight,
  }) async {
    tester.view
      ..physicalSize = screenSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: screenSize,
              // Android à 3 boutons, en bord à bord
              viewPadding: const EdgeInsets.only(bottom: 48),
              systemGestureInsets: const EdgeInsets.only(bottom: 48),
              viewInsets: EdgeInsets.only(bottom: keyboardHeight),
            ),
            child: const AppScaffold(
              bottomNavigationBar: SizedBox(key: navBarKey, height: 56),
              floatingActionButton: SizedBox.square(dimension: 56),
              body: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('places the nav bar above the Android 3-button navigation',
      (tester) async {
    await pumpAppScaffold(tester, keyboardHeight: 0);

    expect(tester.getRect(find.byKey(navBarKey)).bottom, 800 - 48 - 8);
  });

  testWidgets('leaves the nav bar in place under the keyboard', (tester) async {
    await pumpAppScaffold(tester, keyboardHeight: 300);

    expect(tester.getRect(find.byKey(navBarKey)).bottom, 800 - 48 - 8);
    expect(find.byKey(navBarKey).hitTestable(), findsNothing);
  });
}
