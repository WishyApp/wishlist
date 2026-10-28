import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/app/config/config.dart';

void main() {
  const baseEnv = 'SUPABASE_URL=https://example.supabase.co\n'
      'SUPABASE_ANON_KEY=anon-key\n';

  Config configFrom(String envFile) {
    final dotEnv = DotEnv()..testLoad(fileInput: envFile);
    return Config.fromDotEnv(dotEnv);
  }

  group('Config.fromDotEnv', () {
    test('reads the Supabase config', () {
      final config = configFrom(baseEnv);

      expect(config.supabaseConfig.url, 'https://example.supabase.co');
      expect(config.supabaseConfig.anonKey, 'anon-key');
    });

    test('reads SENTRY_DSN when present', () {
      final config = configFrom('${baseEnv}SENTRY_DSN=https://key@sentry.io/1');

      expect(config.sentryDsn, 'https://key@sentry.io/1');
    });

    test('has no Sentry DSN when SENTRY_DSN is absent', () {
      expect(configFrom(baseEnv).sentryDsn, isNull);
    });

    test('has no Sentry DSN when SENTRY_DSN is empty', () {
      expect(configFrom('${baseEnv}SENTRY_DSN=').sentryDsn, isNull);
    });

    for (final malformed in [
      'changeme',
      'https://sentry.io/1',
      'https://key@/1',
      'ftp://key@sentry.io/1',
      'https://key@sentry.io',
    ]) {
      test('ignores the malformed Sentry DSN "$malformed"', () {
        expect(configFrom('${baseEnv}SENTRY_DSN=$malformed').sentryDsn, isNull);
      });
    }

    test('includes the Sentry DSN in equality', () {
      final withDsn =
          configFrom('${baseEnv}SENTRY_DSN=https://key@sentry.io/1');

      expect(withDsn, isNot(configFrom(baseEnv)));
    });

    group('googleSignInConfig', () {
      test('is null without GOOGLE_WEB_CLIENT_ID', () {
        expect(configFrom(baseEnv).googleSignInConfig, isNull);
        expect(
          configFrom('${baseEnv}GOOGLE_WEB_CLIENT_ID= ').googleSignInConfig,
          isNull,
        );
      });

      test('reads the Web client ID', () {
        expect(
          configFrom('${baseEnv}GOOGLE_WEB_CLIENT_ID=web').googleSignInConfig,
          const GoogleSignInConfig(webClientId: 'web'),
        );
      });
    });
  });
}
