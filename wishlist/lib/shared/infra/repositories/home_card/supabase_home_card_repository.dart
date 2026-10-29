import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/home_card/home_card_repository.dart';
import 'package:wishlist/shared/infra/utils/execute_safely.dart';
import 'package:wishlist/shared/models/home_card_definition.dart';

class SupabaseHomeCardRepository implements HomeCardRepository {
  SupabaseHomeCardRepository(this._client);
  final SupabaseClient _client;

  /// RLS already hides disabled rows and editorial cards outside their window.
  /// A row that cannot be parsed (hand-written data) is reported and skipped,
  /// so it cannot take the other cards down with it.
  @override
  Future<List<HomeCardDefinition>> getActiveCards() async {
    final rows = await executeSafely(
      () => _client.from('home_cards').select().order('priority'),
      errorMessage: 'Failed to load the home cards',
    );
    final cards = <HomeCardDefinition>[];
    for (final row in rows) {
      try {
        cards.add(HomeCardDefinition.fromRow(row));
      } catch (e, stackTrace) {
        debugPrint('[Wishy home_cards] skipped row ${row['key']}: $e');
        unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      }
    }
    return cards;
  }
}
