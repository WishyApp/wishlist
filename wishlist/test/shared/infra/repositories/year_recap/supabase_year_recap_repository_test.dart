import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/repositories/year_recap/supabase_year_recap_repository.dart';
import 'package:wishlist/shared/models/year_recap/year_recap.dart';

import '../../../../fixtures/mock_supabase.dart';

/// The result of an rpc call.
class FakeJsonRpc extends Fake implements PostgrestFilterBuilder<dynamic> {
  FakeJsonRpc(this._result);
  final Object? _result;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(dynamic value) onValue, {
    Function? onError,
  }) =>
      Future<dynamic>.value(_result).then(onValue, onError: onError);
}

class MockStorageClient extends Mock implements SupabaseStorageClient {}

class MockStorageFileApi extends Mock implements StorageFileApi {}

Map<String, dynamic> recapJson({
  Object? longestAwaited,
  String key = 'patient',
  String? illustrationPath,
}) =>
    {
      'year': 2026,
      'stats': {
        'received': 3,
        'offered': 2,
        'longest_awaited': longestAwaited,
        'wishes_added': 7,
        'new_friends': 1,
        'max_offered_same_friend': 2,
        'last_minute_bookings': 1,
        'bookings_total': 4,
        'last_minute_share': 0.25,
        'received_on_party_day': 1,
      },
      'profile': {
        'key': key,
        'score': 1.5,
        'illustration_path': illustrationPath,
      },
    };

void main() {
  late MockSupabaseClient client;
  late SupabaseYearRecapRepository repository;

  setUp(() {
    client = MockSupabaseClient();
    repository = SupabaseYearRecapRepository(client);
  });

  void answerWith(Object? result) {
    when(
      () => client.rpc<dynamic>(any(), params: any(named: 'params')),
    ).thenAnswer((_) => FakeJsonRpc(result));
  }

  test('calls get_my_year_recap with the year', () async {
    answerWith(recapJson());

    await repository.getMyYearRecap(2026);

    verify(
      () => client.rpc<dynamic>(
        'get_my_year_recap',
        params: {'p_year': 2026},
      ),
    ).called(1);
  });

  test('parses the stats, the longest awaited wish and the profile', () async {
    answerWith(
      recapJson(
        longestAwaited: {
          'wish_id': 1,
          'wish_name': 'Casque',
          'created_on': '2026-01-11',
          'completed_on': '2026-07-15',
          'days': 185,
        },
        illustrationPath: 'patient.png',
      ),
    );

    final recap = await repository.getMyYearRecap(2026);

    expect(recap.year, 2026);
    expect(recap.stats.received, 3);
    expect(recap.stats.offered, 2);
    expect(recap.stats.wishesAdded, 7);
    expect(recap.stats.newFriends, 1);
    expect(recap.stats.maxOfferedSameFriend, 2);
    expect(recap.stats.lastMinuteBookings, 1);
    expect(recap.stats.bookingsTotal, 4);
    expect(recap.stats.lastMinuteShare, 0.25);
    expect(recap.stats.receivedOnPartyDay, 1);
    final awaited = recap.stats.longestAwaited!;
    expect(awaited.wishId, 1);
    expect(awaited.wishName, 'Casque');
    expect(awaited.createdOn, DateTime(2026, 1, 11));
    expect(awaited.completedOn, DateTime(2026, 7, 15));
    expect(awaited.days, 185);
    expect(recap.profile.key, YearRecapProfileKey.patient);
    expect(recap.profile.score, 1.5);
    expect(recap.profile.illustrationPath, 'patient.png');
  });

  test('a null longest awaited wish and illustration are kept null', () async {
    answerWith(recapJson());

    final recap = await repository.getMyYearRecap(2026);

    expect(recap.stats.longestAwaited, isNull);
    expect(recap.profile.illustrationPath, isNull);
  });

  test('every profile key of the server is known', () async {
    const keys = {
      'patient': YearRecapProfileKey.patient,
      'pere_noel_discret': YearRecapProfileKey.pereNoelDiscret,
      'gate': YearRecapProfileKey.gate,
      'equilibriste': YearRecapProfileKey.equilibriste,
      'reveur': YearRecapProfileKey.reveur,
      'rassembleur': YearRecapProfileKey.rassembleur,
      'ami_fidele': YearRecapProfileKey.amiFidele,
      'dernier_moment': YearRecapProfileKey.dernierMoment,
      'organise': YearRecapProfileKey.organise,
      'minimaliste': YearRecapProfileKey.minimaliste,
    };
    for (final entry in keys.entries) {
      answerWith(recapJson(key: entry.key));

      final recap = await repository.getMyYearRecap(2026);

      expect(recap.profile.key, entry.value, reason: entry.key);
    }
  });

  test('an unknown profile key becomes minimaliste', () async {
    answerWith(recapJson(key: 'brand_new_profile'));

    final recap = await repository.getMyYearRecap(2026);

    expect(recap.profile.key, YearRecapProfileKey.minimaliste);
  });

  test('a failing call is an AppException', () async {
    when(
      () => client.rpc<dynamic>(any(), params: any(named: 'params')),
    ).thenThrow(const PostgrestException(message: 'boom', code: '500'));

    await expectLater(
      repository.getMyYearRecap(2026),
      throwsA(isA<AppException>()),
    );
  });

  test('illustrationUrl asks the public URL in the illustrations bucket', () {
    final storage = MockStorageClient();
    final files = MockStorageFileApi();
    when(() => client.storage).thenReturn(storage);
    when(() => storage.from('year-recap-illustrations')).thenReturn(files);
    when(() => files.getPublicUrl('patient.png'))
        .thenReturn('https://example.com/patient.png');

    expect(
      repository.illustrationUrl('patient.png'),
      'https://example.com/patient.png',
    );
  });
}
