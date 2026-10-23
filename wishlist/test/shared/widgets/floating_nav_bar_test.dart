import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/navigation/floating_nav_bar_navigator.dart';
import 'package:wishlist/shared/widgets/floating_nav_bar.dart';

import '../../fixtures/fake_providers.dart';
import '../../pump_app.dart';

void main() {
  testWidgets('calls onTabChanged once per tap, even after rebuilds',
      (tester) async {
    final calls = <FloatingNavBarTab>[];
    final tabController = TabController(
      length: FloatingNavBarTab.values.length,
      vsync: const TestVSync(),
    );
    addTearDown(tabController.dispose);
    late StateSetter rebuild;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [friendshipsRealtimeOverride()],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return FloatingNavBar(
                  onTabChanged: calls.add,
                  currentTab: FloatingNavBarTab.home,
                  tabController: tabController,
                );
              },
            ),
          ),
        ),
      ),
    );

    for (var i = 0; i < 3; i++) {
      rebuild(() {});
      await tester.pump();
    }

    await tester.tap(find.byIcon(Icons.group));
    await tester.pumpAndSettle();

    expect(calls, [FloatingNavBarTab.friends]);
  });

  testWidgets('the tabs have no tap splash but keep focus and hover overlays',
      (tester) async {
    final tabController = TabController(
      length: FloatingNavBarTab.values.length,
      vsync: const TestVSync(),
    );
    addTearDown(tabController.dispose);

    await tester.pumpApp(
      FloatingNavBar(
        onTabChanged: (_) {},
        currentTab: FloatingNavBarTab.home,
        tabController: tabController,
      ),
      overrides: [friendshipsRealtimeOverride()],
    );

    final tabBarTheme = TabBarTheme.of(tester.element(find.byType(TabBar)));
    final overlayColor = tabBarTheme.overlayColor!;

    expect(tabBarTheme.splashFactory, NoSplash.splashFactory);
    expect(overlayColor.resolve({WidgetState.pressed}), Colors.transparent);
    expect(overlayColor.resolve({WidgetState.focused}), isNull);
    expect(overlayColor.resolve({WidgetState.hovered}), isNull);
  });
}
