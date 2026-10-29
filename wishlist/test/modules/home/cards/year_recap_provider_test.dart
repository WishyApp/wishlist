import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/modules/home/cards/year_recap_provider.dart';
import 'package:wishlist/shared/infra/received_wishes_summary_provider.dart';
import 'package:wishlist/shared/infra/repositories/year_recap/year_recap_repository_provider.dart';
import 'package:wishlist/shared/models/received_wishes_summary/received_wishes_summary.dart';
import 'package:wishlist/shared/models/year_recap/year_recap.dart';

import '../../../fixtures/fake_providers.dart';
import '../../../fixtures/fake_year_recap.dart';

void main() {
  late MockYearRecapRepository repository;

  setUp(() {
    repository = MockYearRecapRepository();
  });

  ProviderContainer containerWith(
    Stream<ReceivedWishesSummary> summaries,
  ) {
    final container = ProviderContainer(
      overrides: [
        supabaseClientOverride(),
        yearRecapRepositoryProvider.overrideWithValue(repository),
        receivedWishesSummaryProvider.overrideWith((ref) => summaries),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('loads the recap of the year asked for from the server', () async {
    when(() => repository.getMyYearRecap(2026)).thenAnswer(
      (_) async => fakeYearRecap(
        stats: const YearRecapStats(received: 4),
        profile: YearRecapProfileKey.gate,
      ),
    );
    final container = containerWith(const Stream.empty());
    final subscription = container.listen(
      yearRecapFactsProvider(2026),
      (_, __) {},
    );

    final recap = await container.read(yearRecapFactsProvider(2026).future);

    expect(recap.stats.received, 4);
    expect(recap.profile.key, YearRecapProfileKey.gate);
    verify(() => repository.getMyYearRecap(2026)).called(1);
    subscription.close();
  });

  test('a new received wish loads the recap again', () async {
    var received = 1;
    when(() => repository.getMyYearRecap(any())).thenAnswer(
      (_) async => fakeYearRecap(stats: YearRecapStats(received: received)),
    );
    final summaries = StreamController<ReceivedWishesSummary>();
    addTearDown(summaries.close);
    summaries.add(
      ReceivedWishesSummary(count: 1, latestCompletedAt: DateTime(2026, 3, 4)),
    );
    final container = containerWith(summaries.stream);
    final subscription = container.listen(
      yearRecapFactsProvider(2026),
      (_, __) {},
    );
    final first = await container.read(yearRecapFactsProvider(2026).future);
    expect(first.stats.received, 1);

    received = 2;
    summaries.add(
      ReceivedWishesSummary(count: 2, latestCompletedAt: DateTime(2026, 5, 6)),
    );
    await Future<void>.delayed(Duration.zero);

    final second = await container.read(yearRecapFactsProvider(2026).future);
    expect(second.stats.received, 2);
    subscription.close();
  });

  test('a summary that did not change does not load the recap again', () async {
    when(() => repository.getMyYearRecap(any()))
        .thenAnswer((_) async => fakeYearRecap());
    final summaries = StreamController<ReceivedWishesSummary>();
    addTearDown(summaries.close);
    final summary = ReceivedWishesSummary(
      count: 1,
      latestCompletedAt: DateTime(2026, 3, 4),
    );
    summaries.add(summary);
    final container = containerWith(summaries.stream);
    // The first value is there before the recap loads
    final summarySubscription = container.listen(
      receivedWishesSummaryProvider,
      (_, __) {},
    );
    await container.read(receivedWishesSummaryProvider.future);
    final subscription = container.listen(
      yearRecapFactsProvider(2026),
      (_, __) {},
    );
    await container.read(yearRecapFactsProvider(2026).future);

    summaries.add(summary);
    await Future<void>.delayed(Duration.zero);
    await container.read(yearRecapFactsProvider(2026).future);

    verify(() => repository.getMyYearRecap(2026)).called(1);
    subscription.close();
    summarySubscription.close();
  });

  test('a summary that cannot be read does not fail the recap', () async {
    when(() => repository.getMyYearRecap(any())).thenAnswer(
      (_) async => fakeYearRecap(stats: const YearRecapStats(received: 1)),
    );
    final container = containerWith(
      Stream<ReceivedWishesSummary>.error(Exception('down')),
    );
    final subscription = container.listen(
      yearRecapFactsProvider(2026),
      (_, __) {},
    );
    await Future<void>.delayed(Duration.zero);

    final result = await container.read(yearRecapFactsProvider(2026).future);
    expect(result.stats.received, 1);
    subscription.close();
  });

  test('a server failure is an error of the provider only', () async {
    when(() => repository.getMyYearRecap(any()))
        .thenThrow(Exception('offline'));
    final container = containerWith(const Stream.empty());
    final subscription = container.listen(
      yearRecapFactsProvider(2026),
      (_, __) {},
    );

    await expectLater(
      container.read(yearRecapFactsProvider(2026).future),
      throwsException,
    );
    subscription.close();
  });
}
