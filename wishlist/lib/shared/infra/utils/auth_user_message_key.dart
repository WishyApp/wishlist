import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/app_exception.dart';

/// Codes d'erreur GoTrue (`AuthException.code`) reconnus. L'enum `ErrorCode`
/// de gotrue n'est pas exporté, d'où les littéraux.
const _samePasswordCode = 'same_password';
const _weakPasswordCode = 'weak_password';
const _reauthenticationNeededCode = 'reauthentication_needed';

/// Retourne la clé de message utilisateur pour [e] si reconnue (ex. ancien
/// mot de passe incorrect, nouveau mot de passe identique), sinon null.
/// Testable unitairement.
AppUserMessageKey? userMessageKeyForAuthException(AuthException e) {
  switch (e.code) {
    case _samePasswordCode:
      return AppUserMessageKey.newPasswordShouldBeDifferent;
    case _weakPasswordCode:
      return AppUserMessageKey.passwordTooWeak;
    case _reauthenticationNeededCode:
      return AppUserMessageKey.reauthenticationNeeded;
  }

  switch (e.statusCode) {
    case '403':
      return AppUserMessageKey.oldPasswordIncorrect;
    case '422':
      // Réponse sans code d'erreur (ancienne API) : seul cas 422 historique.
      return e.code == null
          ? AppUserMessageKey.newPasswordShouldBeDifferent
          : null;
    default:
      return null;
  }
}
