import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/modules/home/cards/year_recap_provider.dart';
import 'package:wishlist/shared/infra/received_wishes_summary_provider.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_repository.dart';
import 'package:wishlist/shared/infra/repositories/user_completed_wish/user_completed_wish_repository_provider.dart';
import 'package:wishlist/shared/models/completed_wish_with_details/completed_wish_with_details.dart';
import 'package:wishlist/shared/models/received_wishes_summary/received_wishes_summary.dart';
import 'package:wishlist/shared/models/wish/wish.dart';

import '../../../fixtures/fake_data.dart';
import '../../../fixtures/fake_providers.dart';

class MockUserCompletedWishRepository extends Mock
    implements UserCompletedWishRepository {}

CompletedWishWithDetails received(int id, DateTime completedAt) {
  return CompletedWishWithDetails(
    wish: Wish(
      id: id,
      createdAt: DateTime(2025, 6, 2),
      name: 'Casque',
      description: '',
      quantity: 1,
      wishlistId: 1,
      updatedBy: fakeFriendUserId1,
      updatedAt: fakeUpdatedAt,
    ),
    fromWishlistId: 1,
    fromWishlistName: 'Liste',
    ownerPseudo: 'Alice',
    ownerId: fakeFriendUserId1,
    completedAt: completedAt,
    quantity: 1,
  );
}

void main() {
  test('a new received wish updates the recap facts', () async {
    final repository = MockUserCompletedWishRepository();
    final wishes = [received(1, DateTime(2026, 3, 4))];
    when(() => repository.getCompletedWishesByUser(any()))
        .thenAnswer((_) async => wishes.toIList());
    final summaries = StreamController<ReceivedWishesSummary>();
    addTearDown(summaries.close);
    summaries.add(
      ReceivedWishesSummary(count: 1, latestCompletedAt: DateTime(2026, 3, 4)),
    );
    final container = ProviderContainer(
      overrides: [
        supabaseClientOverride(),
        bookedWishesRealtimeOverride(),
        userCompletedWishRepositoryProvider.overrideWithValue(repository),
        receivedWishesSummaryProvider.overrideWith((ref) => summaries.stream),
      ],
    );
    addTearDown(container.dispose);
    final facts = container.listen(
      yearRecapFactsProvider(2026),
      (_, __) {},
    );
    expect(
        (await container.read(yearRecapFactsProvider(2026).future))
            .receivedCount,
        1);

    wishes.add(received(2, DateTime(2026, 5, 6)));
    summaries.add(
      ReceivedWishesSummary(count: 2, latestCompletedAt: DateTime(2026, 5, 6)),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
        (await container.read(yearRecapFactsProvider(2026).future))
            .receivedCount,
        2);
    facts.close();
  });
}
