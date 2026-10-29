import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/card_state/supabase_card_state_repository.dart';

import '../../../../fixtures/mock_supabase.dart';

/// An rpc call that succeeds without a result.
class FakeVoidRpc extends Fake implements PostgrestFilterBuilder<void> {
  @override
  Future<R> then<R>(
    FutureOr<R> Function(void value) onValue, {
    Function? onError,
  }) =>
      Future<void>.value().then(onValue, onError: onError);
}

void main() {
  late MockSupabaseClient client;
  late SupabaseCardStateRepository repository;

  setUp(() {
    client = MockSupabaseClient();
    repository = SupabaseCardStateRepository(client);
    when(
      () => client.rpc<void>(any(), params: any(named: 'params')),
    ).thenAnswer((_) => FakeVoidRpc());
  });

  test('dismiss sends the snooze date in UTC', () async {
    final snoozeUntil = DateTime.utc(2026, 12, 29, 8);

    await repository.dismiss('stale_wishlist:9', snoozeUntil: snoozeUntil);

    verify(
      () => client.rpc<void>(
        'dismiss_card',
        params: {
          'p_card_key': 'stale_wishlist:9',
          'p_snooze_until': snoozeUntil.toUtc().toIso8601String(),
        },
      ),
    ).called(1);
  });

  test('dismiss without a snooze sends null', () async {
    await repository.dismiss('booked_reminder:1');

    verify(
      () => client.rpc<void>(
        'dismiss_card',
        params: {'p_card_key': 'booked_reminder:1', 'p_snooze_until': null},
      ),
    ).called(1);
  });

  test('recordShown calls record_card_shown', () async {
    await repository.recordShown('christmas:2026');

    verify(
      () => client.rpc<void>(
        'record_card_shown',
        params: {'p_card_key': 'christmas:2026'},
      ),
    ).called(1);
  });
}
