import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishlist/modules/home/cards/stale_cards_day_store.dart';

void main() {
  final today = DateTime(2026, 10, 30, 10);
  final tomorrow = DateTime(2026, 10, 31, 0, 1);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  StaleCardsDayStore store() =>
      StaleCardsDayStore(prefs: SharedPreferences.getInstance);

  test('starts empty', () {
    final day = StaleCardsDayStore().dayOf('u1', today);

    expect(day.dismissed, isFalse);
    expect(day.shownKeys, isEmpty);
  });

  test('a dismissal and the shown keys come back after a restart', () async {
    final first = store();
    await first.load();
    first
      ..addShown('u1', today, ['q1', 'q2'])
      ..markDismissed('u1', today);
    await pumpEventQueue();

    final second = store();
    await second.load();
    final day = second.dayOf('u1', today);

    expect(day.dismissed, isTrue);
    expect(day.shownKeys, {'q1', 'q2'});
  });

  test('another day or another user starts empty', () async {
    final first = store();
    await first.load();
    first.markDismissed('u1', today);
    await pumpEventQueue();

    final second = store();
    await second.load();

    expect(second.dayOf('u1', tomorrow).dismissed, isFalse);
    expect(second.dayOf('u2', today).dismissed, isFalse);
  });

  test('a store that cannot read the preferences still works in memory',
      () async {
    final broken = StaleCardsDayStore(prefs: () => throw Exception('no'));
    await broken.load();
    broken.markDismissed('u1', today);

    expect(broken.dayOf('u1', today).dismissed, isTrue);
  });
}
