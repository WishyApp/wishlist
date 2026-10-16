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

    test('includes the Sentry DSN in equality', () {
      final withDsn =
          configFrom('${baseEnv}SENTRY_DSN=https://key@sentry.io/1');

      expect(withDsn, isNot(configFrom(baseEnv)));
    });
  });
}
