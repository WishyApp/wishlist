import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/repositories/home_card/home_card_repository.dart';
import 'package:wishlist/shared/infra/utils/execute_safely.dart';
import 'package:wishlist/shared/models/home_card_definition.dart';

/// Reports a row that could not be parsed, with its key.
typedef HomeCardErrorReporter = void Function(
  String key,
  Object error,
  StackTrace stackTrace,
);

class SupabaseHomeCardRepository implements HomeCardRepository {
  SupabaseHomeCardRepository(
    this._client, {
    HomeCardErrorReporter reportError = _reportToSentry,
  }) : _reportError = reportError;
  final SupabaseClient _client;
  final HomeCardErrorReporter _reportError;

  /// Keys already reported during this app session: a bad row stays bad for
  /// every user and every refresh, one event is enough.
  static final _reportedKeys = <String>{};

  @visibleForTesting
  static void resetReportedKeys() => _reportedKeys.clear();

  static void _reportToSentry(String key, Object error, StackTrace stackTrace) {
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) => scope.setTag('home_card', key),
      ),
    );
  }

  /// RLS already hides disabled rows and editorial cards outside their window.
  /// A row that cannot be parsed (hand-written data) is reported and skipped,
  /// so it cannot take the other cards down with it.
  @override
  Future<List<HomeCardDefinition>> getActiveCards() async {
    final rows = await executeSafely(
      () => _client
          .from('home_cards')
          .select()
          .order('priority', ascending: true),
      errorMessage: 'Failed to load the home cards',
    );
    final cards = <HomeCardDefinition>[];
    for (final row in rows) {
      try {
        cards.add(HomeCardDefinition.fromRow(row));
      } catch (e, stackTrace) {
        debugPrint('[Wishy home_cards] skipped row ${row['key']}: $e');
        final key = '${row['key']}';
        if (_reportedKeys.add(key)) {
          _reportError(key, e, stackTrace);
        }
      }
    }
    return cards;
  }
}
