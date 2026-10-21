import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/shared/infra/app_exception.dart';

/// Codes d'erreur GoTrue (`AuthException.code`) reconnus. L'enum `ErrorCode`
/// de gotrue n'est pas exporté, d'où les littéraux.
const _samePasswordCode = 'same_password';
const _weakPasswordCode = 'weak_password';
const _reauthenticationNeededCode = 'reauthentication_needed';
const _invalidCredentialsCode = 'invalid_credentials';
const _legacyInvalidCredentialsMessage = 'Invalid login credentials';

/// Vrai si [e] signifie des identifiants refusés (mauvais mot de passe), par
/// opposition à une erreur réseau ou serveur. Sans code d'erreur (ancienne
/// API), on se rabat sur le message historique de GoTrue.
bool isInvalidCredentialsException(AuthException e) {
  if (e.code != null) {
    return e.code == _invalidCredentialsCode;
  }
  return e.message == _legacyInvalidCredentialsMessage;
}

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
      // Sans code d'erreur (ancienne API) seulement : avec un code, c'est une
      // erreur de session (session_not_found, bad_jwt...). Le vrai « ancien
      // mot de passe incorrect » est levé par AuthService.changePassword
      // avant updateUser.
      return e.code == null ? AppUserMessageKey.oldPasswordIncorrect : null;
    case '422':
      // Réponse sans code d'erreur (ancienne API) : seul cas 422 historique.
      return e.code == null
          ? AppUserMessageKey.newPasswordShouldBeDifferent
          : null;
    default:
      return null;
  }
}
