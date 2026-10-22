import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wishlist/shared/infra/repositories/app_version/app_version_repository.dart';
import 'package:wishlist/shared/infra/repositories/app_version/supabase_app_version_repository.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';

final appVersionRepositoryProvider =
    Provider.autoDispose<AppVersionRepository>((ref) {
  return SupabaseAppVersionRepository(ref.watch(supabaseClientProvider));
});
