import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wishlist/app/config/environment.dart';
import 'package:wishlist/gen/assets.gen.dart';

class Config extends Equatable {
  const Config({
    required this.supabaseConfig,
    this.sentryDsn,
  });

  @visibleForTesting
  factory Config.fromDotEnv(DotEnv dotEnvConfig) {
    final sentryDsn = dotEnvConfig.maybeGet('SENTRY_DSN')?.trim();

    return Config(
      supabaseConfig: SupabaseConfig(
        url: dotEnvConfig.get('SUPABASE_URL'),
        anonKey: dotEnvConfig.get('SUPABASE_ANON_KEY'),
      ),
      sentryDsn:
          sentryDsn != null && _isValidSentryDsn(sentryDsn) ? sentryDsn : null,
    );
  }

  /// A malformed DSN must never prevent the app from starting, it just
  /// disables crash reporting.
  static bool _isValidSentryDsn(String dsn) {
    final uri = Uri.tryParse(dsn);

    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isNotEmpty &&
        uri.pathSegments.any((segment) => segment.isNotEmpty);
  }

  final SupabaseConfig supabaseConfig;

  /// Sentry DSN, null when crash reporting is not configured.
  final String? sentryDsn;

  // Load all environment variables from .env.{environment} file
  static Future<void> _loadEnvironment(
    Environment environment, {
    required DotEnv dotEnvConfig,
  }) async {
    await dotEnvConfig.load(
      fileName: Assets.env.values.map((e) => e).firstWhere(
            (element) =>
                element.contains(environment.toString().split('.').last),
          ),
    );
  }

  static Future<Config> load({
    required Environment environment,
    DotEnv? dotEnvOverride,
  }) async {
    // Well since we need this line to test the others methods
    // we can not cover this line in the tests
    final dotEnvConfig = dotEnvOverride ?? dotenv; // coverage:ignore-line

    await _loadEnvironment(environment, dotEnvConfig: dotEnvConfig);

    return Config.fromDotEnv(dotEnvConfig);
  }

  @override
  List<Object?> get props => [
        supabaseConfig,
        sentryDsn,
      ];
}

class SupabaseConfig extends Equatable {
  const SupabaseConfig({
    required this.url,
    required this.anonKey,
  });

  final String url;
  final String anonKey;

  @override
  List<Object?> get props => [
        url,
        anonKey,
      ];
}
