import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/keyed_realtime_streams.dart';
import 'package:wishlist/shared/infra/repositories/user/user_stream_repository.dart';
import 'package:wishlist/shared/models/profile.dart';

class SupabaseUserStreamRepository implements UserStreamRepository {
  SupabaseUserStreamRepository(this._client);

  final SupabaseClient _client;
  static const _profilesTableName = 'profiles';

  final _streams = KeyedRealtimeStreams(logTag: 'profile');

  @override
  Stream<Profile?> watchProfileById(String userId) {
    final key = 'profile_$userId';

    Future<Profile?> fetch() async {
      final response = await _client
          .from(_profilesTableName)
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response == null ? null : Profile.fromJson(response);
    }

    return _streams.watch<Profile?>(
      key,
      load: fetch,
      channelBuilder: (reload) => _client
          .channel('profile_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: _profilesTableName,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: userId,
            ),
            // Le profil est lu dans le payload, mais passe par le même
            // séquencement que les chargements : un chargement plus ancien qui
            // termine après lui ne l'écrase pas.
            callback: (payload) => reload(
              () async => payload.eventType == PostgresChangeEvent.delete
                  ? null
                  : Profile.fromJson(payload.newRecord),
            ),
          )
          .subscribe(),
    );
  }

  @override
  Future<void> dispose() => _streams.dispose();
}
