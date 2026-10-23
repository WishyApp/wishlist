import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/widgets/birthday_picker.dart';

import '../../pump_app.dart';

const _itemExtent = 40.0;

void main() {
  final dayPicker = find.byKey(const ValueKey('birthday-day-picker'));
  final monthPicker = find.byKey(const ValueKey('birthday-month-picker'));

  Future<List<Birthday>> pumpPicker(
    WidgetTester tester,
    Birthday initial,
  ) async {
    final changes = <Birthday>[];
    await tester.pumpApp(
      Center(
        child: BirthdayPicker(initialValue: initial, onChanged: changes.add),
      ),
    );
    await tester.pumpAndSettle();
    return changes;
  }

  Future<void> scrollMonth(WidgetTester tester, int months) async {
    await tester.drag(monthPicker, Offset(0, -_itemExtent * months));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the initial value with localized month names',
      (tester) async {
    await pumpPicker(tester, const Birthday(month: 3, day: 12));

    expect(find.text('mars'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('clamps 31 to 30 when switching to April', (tester) async {
    final changes = await pumpPicker(tester, const Birthday(month: 3, day: 31));

    await scrollMonth(tester, 1);

    expect(changes.last, const Birthday(month: 4, day: 30));
    expect(find.text('30'), findsOneWidget);
    expect(find.text('31'), findsNothing);
  });

  testWidgets('clamps 31 to 29 when switching to February', (tester) async {
    final changes = await pumpPicker(tester, const Birthday(month: 1, day: 31));

    await scrollMonth(tester, 1);

    expect(changes.last, const Birthday(month: 2, day: 29));
    expect(find.text('29'), findsOneWidget);
  });

  testWidgets('keeps a day that exists in the new month', (tester) async {
    final changes = await pumpPicker(tester, const Birthday(month: 3, day: 12));

    await scrollMonth(tester, 1);

    expect(changes.last, const Birthday(month: 4, day: 12));
  });

  testWidgets('reports the day picked on the day wheel', (tester) async {
    final changes = await pumpPicker(tester, const Birthday(month: 3, day: 12));

    await tester.drag(dayPicker, const Offset(0, -_itemExtent * 2));
    await tester.pumpAndSettle();

    expect(changes.last, const Birthday(month: 3, day: 14));
  });
}
