import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wishlist/app/config/environment.dart';
import 'package:wishlist/gen/assets.gen.dart';

class Config extends Equatable {
  const Config({
    required this.supabaseConfig,
    this.sentryDsn,
    this.googleSignInConfig,
  });

  @visibleForTesting
  factory Config.fromDotEnv(DotEnv dotEnvConfig) {
    final sentryDsn = dotEnvConfig.maybeGet('SENTRY_DSN')?.trim();
    final googleWebClientId = _nonEmpty(
      dotEnvConfig.maybeGet('GOOGLE_WEB_CLIENT_ID'),
    );

    return Config(
      supabaseConfig: SupabaseConfig(
        url: dotEnvConfig.get('SUPABASE_URL'),
        anonKey: dotEnvConfig.get('SUPABASE_ANON_KEY'),
      ),
      sentryDsn:
          sentryDsn != null && _isValidSentryDsn(sentryDsn) ? sentryDsn : null,
      googleSignInConfig: googleWebClientId != null
          ? GoogleSignInConfig(
              webClientId: googleWebClientId,
              iosClientId: _nonEmpty(
                dotEnvConfig.maybeGet('GOOGLE_IOS_CLIENT_ID'),
              ),
            )
          : null,
    );
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
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

  /// Google sign-in client IDs, null when Google sign-in is not configured.
  final GoogleSignInConfig? googleSignInConfig;

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
        googleSignInConfig,
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

/// OAuth client IDs from the Google Cloud console.
class GoogleSignInConfig extends Equatable {
  const GoogleSignInConfig({
    required this.webClientId,
    this.iosClientId,
  });

  /// The Web client: Supabase checks that the ID token was issued to it.
  final String webClientId;

  /// The iOS client, required by the native sign-in on iOS only.
  final String? iosClientId;

  @override
  List<Object?> get props => [
        webClientId,
        iosClientId,
      ];
}
