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

  test('a call about an earlier day is ignored, today keeps its flag', () {
    final store = StaleCardsDayStore()..markDismissed('u1', tomorrow);

    // A build that started before midnight reaches the store late
    expect(store.dayOf('u1', today).dismissed, isFalse);
    store
      ..markDismissed('u2', today)
      ..addShown('u1', today, ['q9']);

    final day = store.dayOf('u1', tomorrow);
    expect(day.dismissed, isTrue);
    expect(day.shownKeys, isEmpty);
    expect(store.dayOf('u2', tomorrow).dismissed, isFalse);
  });

  test('the stack of a swipe is kept as shown, even from the day before', () {
    final store = StaleCardsDayStore()
      ..markDismissed('u1', tomorrow, stackKeys: ['q1', 'q2', 'q3']);

    expect(store.dayOf('u1', tomorrow).shownKeys, {'q1', 'q2', 'q3'});
  });

  test('each user keeps their own state through a user switch', () async {
    final first = store();
    await first.load();
    first
      ..markDismissed('u1', today, stackKeys: ['q1'])
      ..addShown('u2', today, ['q7']);
    await pumpEventQueue();
    final second = store();
    await second.load();

    expect(second.dayOf('u1', today).dismissed, isTrue);
    expect(second.dayOf('u1', today).shownKeys, {'q1'});
    expect(second.dayOf('u2', today).dismissed, isFalse);
    expect(second.dayOf('u2', today).shownKeys, {'q7'});
  });

  test('saved data that cannot be read is ignored as a whole', () async {
    SharedPreferences.setMockInitialValues({
      'stale_cards_day': '{"date":20261030,"users":{"u1":{"shown":["q1"]}}}',
    });
    final broken = store();
    await broken.load();

    expect(broken.dayOf('u1', today).dismissed, isFalse);
    expect(broken.dayOf('u1', today).shownKeys, isEmpty);
  });
}
