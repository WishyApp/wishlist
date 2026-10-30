import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'arb/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Wishy'**
  String get appTitle;

  /// No description provided for @emailField.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get emailField;

  /// No description provided for @validEmailError.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir une adresse e-mail valide'**
  String get validEmailError;

  /// No description provided for @passwordField.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get passwordField;

  /// No description provided for @passwordRequirementMinLength.
  ///
  /// In fr, this message translates to:
  /// **'Au moins 8 caractères'**
  String get passwordRequirementMinLength;

  /// No description provided for @passwordRequirementUppercase.
  ///
  /// In fr, this message translates to:
  /// **'Au moins une majuscule'**
  String get passwordRequirementUppercase;

  /// No description provided for @passwordRequirementLowercase.
  ///
  /// In fr, this message translates to:
  /// **'Au moins une minuscule'**
  String get passwordRequirementLowercase;

  /// No description provided for @passwordRequirementNumber.
  ///
  /// In fr, this message translates to:
  /// **'Au moins un chiffre'**
  String get passwordRequirementNumber;

  /// No description provided for @passwordRequirementSpecialChar.
  ///
  /// In fr, this message translates to:
  /// **'Au moins un caractère spécial'**
  String get passwordRequirementSpecialChar;

  /// No description provided for @passwordSecurityError.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe ne respecte pas tous les critères de sécurité'**
  String get passwordSecurityError;

  /// No description provided for @signIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In fr, this message translates to:
  /// **'S\'inscrire'**
  String get signUp;

  /// No description provided for @dontHaveAccount.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas de compte ?\nCréez-en un !'**
  String get dontHaveAccount;

  /// No description provided for @haveAccount.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà un compte ?\nConnectez-vous !'**
  String get haveAccount;

  /// No description provided for @socialSignInSeparator.
  ///
  /// In fr, this message translates to:
  /// **'ou'**
  String get socialSignInSeparator;

  /// No description provided for @continueWithGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Apple'**
  String get continueWithApple;

  /// No description provided for @googleSignInSafariUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'La connexion avec Google a besoin de Safari, qui n\'est pas disponible sur cet appareil. Connectez-vous avec votre email ou avec Apple.'**
  String get googleSignInSafariUnavailable;

  /// No description provided for @invalidLoginCredentials.
  ///
  /// In fr, this message translates to:
  /// **'Identifiants de connexion invalides'**
  String get invalidLoginCredentials;

  /// No description provided for @userAlreadyRegistered.
  ///
  /// In fr, this message translates to:
  /// **'Cet email est déjà enregistré'**
  String get userAlreadyRegistered;

  /// No description provided for @genericError.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue, veuillez réessayer.'**
  String get genericError;

  /// No description provided for @inputTooLong.
  ///
  /// In fr, this message translates to:
  /// **'La saisie est trop longue.'**
  String get inputTooLong;

  /// No description provided for @wishOverbooked.
  ///
  /// In fr, this message translates to:
  /// **'Ce wish vient d\'être réservé par quelqu\'un d\'autre. Actualise et réessaie.'**
  String get wishOverbooked;

  /// No description provided for @wishQuantityBelowBooked.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de baisser la quantité : une partie de ce wish est déjà réservée.'**
  String get wishQuantityBelowBooked;

  /// No description provided for @networkError.
  ///
  /// In fr, this message translates to:
  /// **'Problème de connexion. Vérifie ton réseau puis réessaie.'**
  String get networkError;

  /// No description provided for @networkErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Problème de connexion'**
  String get networkErrorTitle;

  /// No description provided for @networkErrorDescription.
  ///
  /// In fr, this message translates to:
  /// **'Ta connexion internet semble absente ou trop lente. Vérifie ton Wi-Fi ou tes données mobiles, puis réessaie.'**
  String get networkErrorDescription;

  /// No description provided for @loadingErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger cette page'**
  String get loadingErrorTitle;

  /// No description provided for @loadingErrorDescription.
  ///
  /// In fr, this message translates to:
  /// **'Le problème vient sûrement de chez nous. Réessaie dans quelques instants.'**
  String get loadingErrorDescription;

  /// No description provided for @retryButton.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retryButton;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour requise'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredDescription.
  ///
  /// In fr, this message translates to:
  /// **'Cette version de Wishy n\'est plus prise en charge. Mets l\'application à jour pour continuer.'**
  String get updateRequiredDescription;

  /// No description provided for @updateRequiredNoLinkIosDescription.
  ///
  /// In fr, this message translates to:
  /// **'Cette version de Wishy n\'est plus prise en charge. Mets l\'application à jour depuis TestFlight pour continuer.'**
  String get updateRequiredNoLinkIosDescription;

  /// No description provided for @updateRequiredNoLinkAndroidDescription.
  ///
  /// In fr, this message translates to:
  /// **'Cette version de Wishy n\'est plus prise en charge. Mets l\'application à jour depuis le Play Store pour continuer.'**
  String get updateRequiredNoLinkAndroidDescription;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle version disponible'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableMessage.
  ///
  /// In fr, this message translates to:
  /// **'Mets Wishy à jour pour profiter des dernières nouveautés.'**
  String get updateAvailableMessage;

  /// No description provided for @updateAvailableNoLinkIosMessage.
  ///
  /// In fr, this message translates to:
  /// **'Mets Wishy à jour depuis TestFlight pour profiter des dernières nouveautés.'**
  String get updateAvailableNoLinkIosMessage;

  /// No description provided for @updateAvailableNoLinkAndroidMessage.
  ///
  /// In fr, this message translates to:
  /// **'Mets Wishy à jour depuis le Play Store pour profiter des dernières nouveautés.'**
  String get updateAvailableNoLinkAndroidMessage;

  /// No description provided for @updateButton.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour'**
  String get updateButton;

  /// No description provided for @updateLaterButton.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get updateLaterButton;

  /// No description provided for @pseudoField.
  ///
  /// In fr, this message translates to:
  /// **'Pseudo'**
  String get pseudoField;

  /// No description provided for @validPseudoError.
  ///
  /// In fr, this message translates to:
  /// **'Le pseudo ne peut pas être vide'**
  String get validPseudoError;

  /// No description provided for @pseudoAlreadyExists.
  ///
  /// In fr, this message translates to:
  /// **'Ce pseudo est déjà utilisé'**
  String get pseudoAlreadyExists;

  /// No description provided for @savePseudo.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get savePseudo;

  /// No description provided for @pseudoStepTitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisis ton pseudo'**
  String get pseudoStepTitle;

  /// No description provided for @pseudoStepExplanation.
  ///
  /// In fr, this message translates to:
  /// **'C\'est le nom que tes amis verront dans Wishy.'**
  String get pseudoStepExplanation;

  /// No description provided for @bookedWishesScreenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réservations'**
  String get bookedWishesScreenTitle;

  /// No description provided for @bookedWishesEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune réservation'**
  String get bookedWishesEmptyTitle;

  /// No description provided for @bookedWishesEmptyCallToAction.
  ///
  /// In fr, this message translates to:
  /// **'Explorer les wishlists de vos amis'**
  String get bookedWishesEmptyCallToAction;

  /// No description provided for @settingsScreenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settingsScreenTitle;

  /// No description provided for @settingsScreenEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get settingsScreenEmail;

  /// No description provided for @settingsScreenEmailModify.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get settingsScreenEmailModify;

  /// No description provided for @settingsScreenDisconnect.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get settingsScreenDisconnect;

  /// No description provided for @settingsScreenDisconnectDialogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get settingsScreenDisconnectDialogTitle;

  /// No description provided for @settingsScreenDisconnectDialogExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Es-tu sûr de vouloir te déconnecter ?'**
  String get settingsScreenDisconnectDialogExplanation;

  /// No description provided for @settingsScreenPasswordModify.
  ///
  /// In fr, this message translates to:
  /// **'Modifier mon mot de passe'**
  String get settingsScreenPasswordModify;

  /// No description provided for @changePasswordScreenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get changePasswordScreenTitle;

  /// No description provided for @oldPasswordField.
  ///
  /// In fr, this message translates to:
  /// **'Ancien mot de passe'**
  String get oldPasswordField;

  /// No description provided for @newPasswordField.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get newPasswordField;

  /// No description provided for @confirmNewPasswordField.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le nouveau mot de passe'**
  String get confirmNewPasswordField;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In fr, this message translates to:
  /// **'Les mots de passe ne correspondent pas'**
  String get passwordsDoNotMatch;

  /// No description provided for @oldPasswordIncorrect.
  ///
  /// In fr, this message translates to:
  /// **'Ancien mot de passe incorrect.'**
  String get oldPasswordIncorrect;

  /// No description provided for @changePasswordConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get changePasswordConfirm;

  /// No description provided for @newPasswordShouldBeDifferent.
  ///
  /// In fr, this message translates to:
  /// **'Le nouveau mot de passe doit être différent de l\'ancien.'**
  String get newPasswordShouldBeDifferent;

  /// No description provided for @passwordTooWeak.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe est trop faible, choisissez-en un autre.'**
  String get passwordTooWeak;

  /// No description provided for @reauthenticationNeeded.
  ///
  /// In fr, this message translates to:
  /// **'Votre session a expiré, veuillez recommencer.'**
  String get reauthenticationNeeded;

  /// No description provided for @changePseudoScreenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pseudo'**
  String get changePseudoScreenTitle;

  /// No description provided for @newPseudoField.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau pseudo'**
  String get newPseudoField;

  /// No description provided for @changePseudoConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get changePseudoConfirm;

  /// No description provided for @changePseudoSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Pseudo modifié avec succès !'**
  String get changePseudoSuccess;

  /// No description provided for @editProfileScreenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le profil'**
  String get editProfileScreenTitle;

  /// No description provided for @editProfilePseudo.
  ///
  /// In fr, this message translates to:
  /// **'Pseudo'**
  String get editProfilePseudo;

  /// No description provided for @editProfileBirthday.
  ///
  /// In fr, this message translates to:
  /// **'Anniversaire'**
  String get editProfileBirthday;

  /// No description provided for @editProfileBirthdayNotSet.
  ///
  /// In fr, this message translates to:
  /// **'Non renseigné'**
  String get editProfileBirthdayNotSet;

  /// No description provided for @editProfilePrivacy.
  ///
  /// In fr, this message translates to:
  /// **'Seuls tes amis voient ton anniversaire. Ton pseudo et ta photo sont visibles par tous.'**
  String get editProfilePrivacy;

  /// No description provided for @changeBirthdayScreenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Anniversaire'**
  String get changeBirthdayScreenTitle;

  /// No description provided for @changeBirthdayExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Seuls tes amis le verront.'**
  String get changeBirthdayExplanation;

  /// No description provided for @changeBirthdayConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get changeBirthdayConfirm;

  /// No description provided for @changeBirthdayRemove.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon anniversaire'**
  String get changeBirthdayRemove;

  /// No description provided for @changeBirthdaySuccess.
  ///
  /// In fr, this message translates to:
  /// **'Anniversaire enregistré !'**
  String get changeBirthdaySuccess;

  /// No description provided for @changeBirthdayRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Anniversaire supprimé !'**
  String get changeBirthdayRemoved;

  /// No description provided for @birthdayStepTitle.
  ///
  /// In fr, this message translates to:
  /// **'C\'est quand ton anniversaire ?'**
  String get birthdayStepTitle;

  /// No description provided for @birthdayStepExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Seuls tes amis le verront.'**
  String get birthdayStepExplanation;

  /// No description provided for @birthdayStepLater.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get birthdayStepLater;

  /// No description provided for @friendBirthdayBadge.
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =0{aujourd\'hui} =1{demain} other{dans {days} j}}'**
  String friendBirthdayBadge(int days);

  /// No description provided for @friendBirthdayWithCountdown.
  ///
  /// In fr, this message translates to:
  /// **'{date} · {days, plural, =0{aujourd\'hui !} =1{demain} other{dans {days} jours}}'**
  String friendBirthdayWithCountdown(String date, int days);

  /// No description provided for @changePasswordSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe changé avec succès !'**
  String get changePasswordSuccess;

  /// No description provided for @settingsScreenDeleteAccount.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get settingsScreenDeleteAccount;

  /// No description provided for @settingsScreenDeleteAccountDialogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get settingsScreenDeleteAccountDialogTitle;

  /// No description provided for @settingsScreenDeleteAccountDialogExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Es-tu sûr de vouloir supprimer ton compte ? Cette action est irréversible et toutes tes données seront définitivement supprimées.'**
  String get settingsScreenDeleteAccountDialogExplanation;

  /// No description provided for @deleteAccountSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Compte supprimé avec succès !'**
  String get deleteAccountSuccess;

  /// No description provided for @confirmDialogConfirmButtonLabel.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get confirmDialogConfirmButtonLabel;

  /// No description provided for @noWishlist.
  ///
  /// In fr, this message translates to:
  /// **'Aucune wishlist'**
  String get noWishlist;

  /// No description provided for @createButton.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get createButton;

  /// No description provided for @createWishlist.
  ///
  /// In fr, this message translates to:
  /// **'Créer une wishlist'**
  String get createWishlist;

  /// No description provided for @name.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get name;

  /// No description provided for @cancelButton.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancelButton;

  /// No description provided for @closeDialog.
  ///
  /// In fr, this message translates to:
  /// **'Fermer la fenêtre contextuelle'**
  String get closeDialog;

  /// No description provided for @fiendsScreenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Amis'**
  String get fiendsScreenTitle;

  /// No description provided for @noFriend.
  ///
  /// In fr, this message translates to:
  /// **'Aucun ami'**
  String get noFriend;

  /// No description provided for @addButton.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get addButton;

  /// No description provided for @emailOrPseudoHint.
  ///
  /// In fr, this message translates to:
  /// **'Email ou pseudo'**
  String get emailOrPseudoHint;

  /// No description provided for @noUserFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun utilisateur trouvé'**
  String get noUserFound;

  /// No description provided for @friendDetailsRemove.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get friendDetailsRemove;

  /// No description provided for @removeFriendConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'Es-tu sûr de vouloir supprimer cet ami ?'**
  String get removeFriendConfirmation;

  /// No description provided for @removeFriendSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Ami supprimé avec succès !'**
  String get removeFriendSuccess;

  /// No description provided for @numberOfWishlists.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0 {0 wishlist} =1 {1 wishlist} other {{count} wishlists}}'**
  String numberOfWishlists(num count);

  /// No description provided for @numberOfWishs.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0 {0 wish} =1 {1 wish} other {{count} wishs}}'**
  String numberOfWishs(num count);

  /// No description provided for @friendDetailsMutualFriendsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Amis en commun'**
  String get friendDetailsMutualFriendsTitle;

  /// No description provided for @friendDetailsNoMutualFriends.
  ///
  /// In fr, this message translates to:
  /// **'Aucun ami en commun'**
  String get friendDetailsNoMutualFriends;

  /// No description provided for @seeAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir plus'**
  String get seeAll;

  /// No description provided for @hide.
  ///
  /// In fr, this message translates to:
  /// **'Masquer'**
  String get hide;

  /// No description provided for @friendDetailsWishlistsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Wishlists publiques'**
  String get friendDetailsWishlistsTitle;

  /// No description provided for @wishlistsScreenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Wishlists'**
  String get wishlistsScreenTitle;

  /// No description provided for @wishlistStatusPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get wishlistStatusPending;

  /// No description provided for @wishlistStatusBooked.
  ///
  /// In fr, this message translates to:
  /// **'Réservés'**
  String get wishlistStatusBooked;

  /// No description provided for @wishlistSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un wish...'**
  String get wishlistSearchHint;

  /// No description provided for @bookedWishesSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Par wish ou pseudo...'**
  String get bookedWishesSearchHint;

  /// No description provided for @wishlistNoWish.
  ///
  /// In fr, this message translates to:
  /// **'Aucun wish'**
  String get wishlistNoWish;

  /// No description provided for @wishlistNoWishBooked.
  ///
  /// In fr, this message translates to:
  /// **'Aucun wish réservé'**
  String get wishlistNoWishBooked;

  /// No description provided for @wishlistNoWishBookedDisplayed.
  ///
  /// In fr, this message translates to:
  /// **'Tu as choisi de ne pas afficher les wishs réservés'**
  String get wishlistNoWishBookedDisplayed;

  /// No description provided for @wishlistAddWish.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un wish'**
  String get wishlistAddWish;

  /// No description provided for @createWishBottomSheetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Créer un wish'**
  String get createWishBottomSheetTitle;

  /// No description provided for @createWishSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Wish créé avec succès !'**
  String get createWishSuccess;

  /// No description provided for @editWishBottomSheetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier un wish'**
  String get editWishBottomSheetTitle;

  /// No description provided for @deleteWish.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le wish'**
  String get deleteWish;

  /// No description provided for @deleteWishConfirmationMessage.
  ///
  /// In fr, this message translates to:
  /// **'Es-tu sûr de vouloir supprimer ce wish ?'**
  String get deleteWishConfirmationMessage;

  /// No description provided for @deleteWishSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Wish supprimé avec succès !'**
  String get deleteWishSuccess;

  /// No description provided for @editButton.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get editButton;

  /// No description provided for @wishNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get wishNameLabel;

  /// No description provided for @wishPriceLabel.
  ///
  /// In fr, this message translates to:
  /// **'Prix'**
  String get wishPriceLabel;

  /// No description provided for @wishQuantityLabel.
  ///
  /// In fr, this message translates to:
  /// **'Quantité'**
  String get wishQuantityLabel;

  /// No description provided for @wishLinkLabel.
  ///
  /// In fr, this message translates to:
  /// **'Lien'**
  String get wishLinkLabel;

  /// No description provided for @wishDescriptionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get wishDescriptionLabel;

  /// No description provided for @wishImageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Image du wish'**
  String get wishImageLabel;

  /// No description provided for @uploadImage.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une image'**
  String get uploadImage;

  /// No description provided for @wishNameError.
  ///
  /// In fr, this message translates to:
  /// **'Le nom du wish est requis'**
  String get wishNameError;

  /// No description provided for @notNullError.
  ///
  /// In fr, this message translates to:
  /// **'Ce champ est requis'**
  String get notNullError;

  /// No description provided for @invalidNumber.
  ///
  /// In fr, this message translates to:
  /// **'Nombre invalide'**
  String get invalidNumber;

  /// No description provided for @numberRangeError.
  ///
  /// In fr, this message translates to:
  /// **'Saisis un nombre entre {min} et {max}'**
  String numberRangeError(Object max, Object min);

  /// No description provided for @openLink.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le lien'**
  String get openLink;

  /// No description provided for @paste.
  ///
  /// In fr, this message translates to:
  /// **'Coller'**
  String get paste;

  /// No description provided for @linkNotValid.
  ///
  /// In fr, this message translates to:
  /// **'Le lien n\'est pas valide !'**
  String get linkNotValid;

  /// No description provided for @iWantToGiveIt.
  ///
  /// In fr, this message translates to:
  /// **'Je veux l\'offrir'**
  String get iWantToGiveIt;

  /// No description provided for @cancelBooking.
  ///
  /// In fr, this message translates to:
  /// **'Annuler ma réservation'**
  String get cancelBooking;

  /// No description provided for @modifyBooking.
  ///
  /// In fr, this message translates to:
  /// **'Modifier ma réservation'**
  String get modifyBooking;

  /// No description provided for @modifyCompletedQuantity.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la quantité complétée'**
  String get modifyCompletedQuantity;

  /// No description provided for @completedWishOptions.
  ///
  /// In fr, this message translates to:
  /// **'Options du wish'**
  String get completedWishOptions;

  /// No description provided for @modifyCompletionDate.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la date de complétion'**
  String get modifyCompletionDate;

  /// No description provided for @cancelBookingDialogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la réservation'**
  String get cancelBookingDialogTitle;

  /// No description provided for @cancelBookingDialogExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Es-tu sûr de vouloir annuler cette réservation ?'**
  String get cancelBookingDialogExplanation;

  /// No description provided for @noDescription.
  ///
  /// In fr, this message translates to:
  /// **'Aucune description'**
  String get noDescription;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @updateSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour effectuée avec succès !'**
  String get updateSuccess;

  /// No description provided for @deleteWishlist.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ma wishlist'**
  String get deleteWishlist;

  /// No description provided for @deleteWishlistConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'Es-tu sûr de vouloir supprimer cette wishlist ?'**
  String get deleteWishlistConfirmation;

  /// No description provided for @deleteWishlistWishesWarning.
  ///
  /// In fr, this message translates to:
  /// **'Les wishs non complétés seront supprimés. Les wishs complétés resteront dans ton historique.'**
  String get deleteWishlistWishesWarning;

  /// No description provided for @deleteWishlistSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Wishlist supprimée avec succès !'**
  String get deleteWishlistSuccess;

  /// No description provided for @wishlistDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Cette wishlist a été supprimée'**
  String get wishlistDeleted;

  /// No description provided for @wishUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Ce wish n\'est plus disponible'**
  String get wishUnavailable;

  /// No description provided for @sortWishs.
  ///
  /// In fr, this message translates to:
  /// **'Trier les wishs'**
  String get sortWishs;

  /// No description provided for @sortByFavorite.
  ///
  /// In fr, this message translates to:
  /// **'Par favoris'**
  String get sortByFavorite;

  /// No description provided for @sortByAlphabetical.
  ///
  /// In fr, this message translates to:
  /// **'Par ordre alphabétique'**
  String get sortByAlphabetical;

  /// No description provided for @sortByPrice.
  ///
  /// In fr, this message translates to:
  /// **'Par prix'**
  String get sortByPrice;

  /// No description provided for @sortByDate.
  ///
  /// In fr, this message translates to:
  /// **'Par date de création'**
  String get sortByDate;

  /// No description provided for @sortByCompletedAt.
  ///
  /// In fr, this message translates to:
  /// **'Par date de complétion'**
  String get sortByCompletedAt;

  /// No description provided for @sortByBookingCount.
  ///
  /// In fr, this message translates to:
  /// **'Par nombre de réservations'**
  String get sortByBookingCount;

  /// No description provided for @selectQuantityToGive.
  ///
  /// In fr, this message translates to:
  /// **'Quelle quantité souhaites-tu offrir ?'**
  String get selectQuantityToGive;

  /// No description provided for @selectQuantityToComplete.
  ///
  /// In fr, this message translates to:
  /// **'Quelle quantité as-tu complétée ?'**
  String get selectQuantityToComplete;

  /// No description provided for @wishReservedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Wish réservé avec succès !'**
  String get wishReservedSuccess;

  /// No description provided for @quantityCannotBeLowerThanBooked.
  ///
  /// In fr, this message translates to:
  /// **'La quantité ne peut pas être inférieure à {bookedQuantity} (quantité déjà réservée)'**
  String quantityCannotBeLowerThanBooked(Object bookedQuantity);

  /// No description provided for @deleteSelectedWishes.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer les wishs'**
  String get deleteSelectedWishes;

  /// No description provided for @deleteSelectedWishConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer ce wish ?'**
  String get deleteSelectedWishConfirmation;

  /// No description provided for @deleteSelectedWishesConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer ces {count} wishs ?'**
  String deleteSelectedWishesConfirmation(int count);

  /// No description provided for @wishesDeleted.
  ///
  /// In fr, this message translates to:
  /// **'{count} wishs supprimés avec succès !'**
  String wishesDeleted(int count);

  /// No description provided for @moveWishes.
  ///
  /// In fr, this message translates to:
  /// **'Déplacer des wishs'**
  String get moveWishes;

  /// No description provided for @moveButton.
  ///
  /// In fr, this message translates to:
  /// **'Déplacer'**
  String get moveButton;

  /// No description provided for @reintegrateWish.
  ///
  /// In fr, this message translates to:
  /// **'Réintégrer un wish'**
  String get reintegrateWish;

  /// No description provided for @reintegrateWishExplanation.
  ///
  /// In fr, this message translates to:
  /// **'La wishlist d\'origine de ce wish a été supprimée, sélectionne la wishlist vers laquelle tu veux le réintégrer :'**
  String get reintegrateWishExplanation;

  /// No description provided for @reintegrateButton.
  ///
  /// In fr, this message translates to:
  /// **'Réintégrer'**
  String get reintegrateButton;

  /// No description provided for @selectWishlist.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner une wishlist'**
  String get selectWishlist;

  /// No description provided for @selectDestinationWishlist.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionne la wishlist vers laquelle tu veux déplacer {count, plural, =1{ce wish} other{ces {count} wishs}} :'**
  String selectDestinationWishlist(int count);

  /// No description provided for @noOtherWishlistsAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Aucune autre wishlist disponible'**
  String get noOtherWishlistsAvailable;

  /// No description provided for @closeButton.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get closeButton;

  /// No description provided for @errorLoadingWishlists.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du chargement des wishlists'**
  String get errorLoadingWishlists;

  /// No description provided for @wishesMoved.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Wish déplacé avec succès !} other{{count} wishs déplacés avec succès !}}'**
  String wishesMoved(int count);

  /// No description provided for @avatarOptions.
  ///
  /// In fr, this message translates to:
  /// **'Modification de l\'avatar'**
  String get avatarOptions;

  /// No description provided for @chooseFromGallery.
  ///
  /// In fr, this message translates to:
  /// **'Choisir depuis la galerie'**
  String get chooseFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get takePhoto;

  /// No description provided for @imageOptions.
  ///
  /// In fr, this message translates to:
  /// **'Ajout de l\'image'**
  String get imageOptions;

  /// No description provided for @cropImageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Recadrer l\'image'**
  String get cropImageTitle;

  /// No description provided for @cropImageCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cropImageCancel;

  /// No description provided for @cropImageValidate.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get cropImageValidate;

  /// No description provided for @removeImage.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'image'**
  String get removeImage;

  /// No description provided for @removeImageConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'Es-tu sûr de vouloir supprimer cette image ?'**
  String get removeImageConfirmation;

  /// No description provided for @avatarLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du chargement de l\'image'**
  String get avatarLoadError;

  /// No description provided for @forgotPasswordButton.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get forgotPasswordButton;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordDescription.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir votre adresse e-mail afin de recevoir le lien de réinitialisation de votre mot de passe.'**
  String get forgotPasswordDescription;

  /// No description provided for @forgotPasswordSendButton.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get forgotPasswordSendButton;

  /// No description provided for @forgotPasswordEmailSent.
  ///
  /// In fr, this message translates to:
  /// **'Un e-mail de réinitialisation a été envoyé !'**
  String get forgotPasswordEmailSent;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser le mot de passe'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordDescription.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre nouveau mot de passe.'**
  String get resetPasswordDescription;

  /// No description provided for @resetPasswordConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser'**
  String get resetPasswordConfirm;

  /// No description provided for @resetPasswordSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe réinitialisé avec succès ! Reconnectez-vous avec votre nouveau mot de passe.'**
  String get resetPasswordSuccess;

  /// No description provided for @resetPasswordLinkExpired.
  ///
  /// In fr, this message translates to:
  /// **'Le lien de réinitialisation a expiré. Veuillez en demander un nouveau.'**
  String get resetPasswordLinkExpired;

  /// No description provided for @settingsSignedInAs.
  ///
  /// In fr, this message translates to:
  /// **'Connecté en tant que'**
  String get settingsSignedInAs;

  /// No description provided for @settingsGeneral.
  ///
  /// In fr, this message translates to:
  /// **'Général'**
  String get settingsGeneral;

  /// No description provided for @settingsAbout.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get settingsAbout;

  /// No description provided for @settingsTermsOfUse.
  ///
  /// In fr, this message translates to:
  /// **'Conditions d\'utilisation'**
  String get settingsTermsOfUse;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In fr, this message translates to:
  /// **'Politique de confidentialité'**
  String get settingsPrivacyPolicy;

  /// No description provided for @completedWishesScreenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Wishs complétés'**
  String get completedWishesScreenTitle;

  /// No description provided for @completedWishesEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun wish complété'**
  String get completedWishesEmptyTitle;

  /// No description provided for @markWishAsCompleted.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme complété'**
  String get markWishAsCompleted;

  /// No description provided for @unmarkWishAsCompleted.
  ///
  /// In fr, this message translates to:
  /// **'Retirer des complétés'**
  String get unmarkWishAsCompleted;

  /// No description provided for @unmarkWishConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer des wishs complétés'**
  String get unmarkWishConfirmTitle;

  /// No description provided for @unmarkWishConfirmMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce wish redeviendra visible dans la wishlist \"{wishlistName}\".'**
  String unmarkWishConfirmMessage(String wishlistName);

  /// No description provided for @unmarkWishArchivedConfirmMessage.
  ///
  /// In fr, this message translates to:
  /// **'Choisis une wishlist dans laquelle remettre ce wish.'**
  String get unmarkWishArchivedConfirmMessage;

  /// No description provided for @deletedWishlist.
  ///
  /// In fr, this message translates to:
  /// **'Wishlist supprimée'**
  String get deletedWishlist;

  /// No description provided for @friendCompletedWishesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Wishs complétés'**
  String get friendCompletedWishesTitle;

  /// No description provided for @seeAllCompletedWishes.
  ///
  /// In fr, this message translates to:
  /// **'Tout voir'**
  String get seeAllCompletedWishes;

  /// No description provided for @completionDateDialogTitle.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Quand l\'as-tu reçu ?} other{Quand les as-tu reçus ?}}'**
  String completionDateDialogTitle(int count);

  /// No description provided for @completionDateDialogExplanation.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Sélectionne la date à laquelle ce wish t\'a été offert.} other{Sélectionne la date à laquelle ces {count} wishs t\'ont été offerts.}}'**
  String completionDateDialogExplanation(int count);

  /// No description provided for @completeButton.
  ///
  /// In fr, this message translates to:
  /// **'Compléter'**
  String get completeButton;

  /// No description provided for @continueButton.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueButton;

  /// No description provided for @wishesCompletedSnackBar.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Ajouté à tes wishs complétés !} other{Ajoutés à tes wishs complétés !}}'**
  String wishesCompletedSnackBar(int count);

  /// No description provided for @snackBarSeeAction.
  ///
  /// In fr, this message translates to:
  /// **'Voir'**
  String get snackBarSeeAction;

  /// No description provided for @relativeDateToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get relativeDateToday;

  /// No description provided for @relativeDateYesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get relativeDateYesterday;

  /// No description provided for @relativeDateDaysAgo.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count} jours'**
  String relativeDateDaysAgo(int count);

  /// No description provided for @relativeDateWeeksAgo.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1 {Il y a 1 semaine} other {Il y a {count} semaines}}'**
  String relativeDateWeeksAgo(int count);

  /// No description provided for @bookedWishesTabToGive.
  ///
  /// In fr, this message translates to:
  /// **'À offrir'**
  String get bookedWishesTabToGive;

  /// No description provided for @bookedWishesTabGiven.
  ///
  /// In fr, this message translates to:
  /// **'Offerts'**
  String get bookedWishesTabGiven;

  /// No description provided for @bookedWishesToGiveCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 à offrir} =1{1 à offrir} other{{count} à offrir}}'**
  String bookedWishesToGiveCount(int count);

  /// No description provided for @bookedWishesGivenCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 offert} =1{1 offert} other{{count} offerts}}'**
  String bookedWishesGivenCount(int count);

  /// No description provided for @bookedWishesNothingToGive.
  ///
  /// In fr, this message translates to:
  /// **'Plus rien à offrir : tout a été reçu'**
  String get bookedWishesNothingToGive;

  /// No description provided for @bookedWishesNothingGiven.
  ///
  /// In fr, this message translates to:
  /// **'Les wishs réservés que tes amis ont reçus apparaîtront ici'**
  String get bookedWishesNothingGiven;

  /// No description provided for @bookedWishReceivedOn.
  ///
  /// In fr, this message translates to:
  /// **'Reçu le {date}'**
  String bookedWishReceivedOn(String date);

  /// No description provided for @wishlistSelectionCountLabel.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{sélectionné} =1{sélectionné} other{sélectionnés}}'**
  String wishlistSelectionCountLabel(int count);

  /// No description provided for @wishlistSelectionCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 sélectionné} =1{1 sélectionné} other{{count} sélectionnés}}'**
  String wishlistSelectionCount(int count);

  /// No description provided for @wishlistSelectAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout sélectionner'**
  String get wishlistSelectAll;

  /// No description provided for @wishlistExitSelection.
  ///
  /// In fr, this message translates to:
  /// **'Quitter la sélection'**
  String get wishlistExitSelection;

  /// No description provided for @wishlistSelectionComplete.
  ///
  /// In fr, this message translates to:
  /// **'Compléter'**
  String get wishlistSelectionComplete;

  /// No description provided for @wishlistSelectionMove.
  ///
  /// In fr, this message translates to:
  /// **'Déplacer'**
  String get wishlistSelectionMove;

  /// No description provided for @wishlistSelectionDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get wishlistSelectionDelete;

  /// No description provided for @wishlistSettingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get wishlistSettingsTitle;

  /// No description provided for @wishlistNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la wishlist'**
  String get wishlistNameLabel;

  /// No description provided for @wishlistNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Donne un nom à ta wishlist'**
  String get wishlistNameRequired;

  /// No description provided for @wishlistColorLabel.
  ///
  /// In fr, this message translates to:
  /// **'Couleur'**
  String get wishlistColorLabel;

  /// No description provided for @colorBlue.
  ///
  /// In fr, this message translates to:
  /// **'Bleu'**
  String get colorBlue;

  /// No description provided for @colorPurple.
  ///
  /// In fr, this message translates to:
  /// **'Violet'**
  String get colorPurple;

  /// No description provided for @colorYellow.
  ///
  /// In fr, this message translates to:
  /// **'Jaune'**
  String get colorYellow;

  /// No description provided for @colorGreen.
  ///
  /// In fr, this message translates to:
  /// **'Vert'**
  String get colorGreen;

  /// No description provided for @publicWishlistLabel.
  ///
  /// In fr, this message translates to:
  /// **'Wishlist publique'**
  String get publicWishlistLabel;

  /// No description provided for @wishlistPublicDescription.
  ///
  /// In fr, this message translates to:
  /// **'Tes proches peuvent la voir et tu peux la partager par lien.'**
  String get wishlistPublicDescription;

  /// No description provided for @wishlistPrivateDescription.
  ///
  /// In fr, this message translates to:
  /// **'Toi seul la vois. Le partage par lien est désactivé.'**
  String get wishlistPrivateDescription;

  /// No description provided for @seeBookedWishesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Voir ce qui est réservé'**
  String get seeBookedWishesLabel;

  /// No description provided for @seeBookedWishesOnDescription.
  ///
  /// In fr, this message translates to:
  /// **'Tu vois quels wishs ont été réservés. Adieu la surprise !'**
  String get seeBookedWishesOnDescription;

  /// No description provided for @seeBookedWishesOffDescription.
  ///
  /// In fr, this message translates to:
  /// **'Tu ne sais pas ce qui a été réservé : la surprise reste entière.'**
  String get seeBookedWishesOffDescription;

  /// No description provided for @deleteButton.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get deleteButton;

  /// No description provided for @unsavedChangesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quitter sans enregistrer ?'**
  String get unsavedChangesTitle;

  /// No description provided for @unsavedChangesMessage.
  ///
  /// In fr, this message translates to:
  /// **'Tes modifications seront perdues.'**
  String get unsavedChangesMessage;

  /// No description provided for @unsavedChangesLeave.
  ///
  /// In fr, this message translates to:
  /// **'Quitter sans enregistrer'**
  String get unsavedChangesLeave;

  /// No description provided for @unsavedChangesKeepEditing.
  ///
  /// In fr, this message translates to:
  /// **'Continuer à modifier'**
  String get unsavedChangesKeepEditing;

  /// No description provided for @wishlistSettingsOwnerOnly.
  ///
  /// In fr, this message translates to:
  /// **'Seul le propriétaire de cette wishlist peut modifier ses paramètres'**
  String get wishlistSettingsOwnerOnly;

  /// No description provided for @homeMyWishlists.
  ///
  /// In fr, this message translates to:
  /// **'Mes wishlists'**
  String get homeMyWishlists;

  /// No description provided for @homeNoWishlist.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de wishlist'**
  String get homeNoWishlist;

  /// No description provided for @homeReceivedWishes.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1 {1 wish reçu} other {{count} wishs reçus}}'**
  String homeReceivedWishes(num count);

  /// No description provided for @homeCardHide.
  ///
  /// In fr, this message translates to:
  /// **'Masquer'**
  String get homeCardHide;

  /// No description provided for @homeCardLater.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get homeCardLater;

  /// No description provided for @homeCardHidden.
  ///
  /// In fr, this message translates to:
  /// **'Carte masquée'**
  String get homeCardHidden;

  /// No description provided for @homeCardPostponed.
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =1{Reportée à demain} other{Reportée de {days} jours}}'**
  String homeCardPostponed(int days);

  /// No description provided for @homeCardFriendBirthdayTodayOverline.
  ///
  /// In fr, this message translates to:
  /// **'C\'est aujourd\'hui !'**
  String get homeCardFriendBirthdayTodayOverline;

  /// No description provided for @homeCardFriendBirthdayTodayTitle.
  ///
  /// In fr, this message translates to:
  /// **'Joyeux anniversaire à {pseudo}'**
  String homeCardFriendBirthdayTodayTitle(String pseudo);

  /// No description provided for @homeCardSeeTheirList.
  ///
  /// In fr, this message translates to:
  /// **'Voir sa liste'**
  String get homeCardSeeTheirList;

  /// No description provided for @homeCardFriendBirthdaySoonTitle.
  ///
  /// In fr, this message translates to:
  /// **'Anniversaire de {pseudo}'**
  String homeCardFriendBirthdaySoonTitle(String pseudo);

  /// No description provided for @homeCardSeeTheirWishlists.
  ///
  /// In fr, this message translates to:
  /// **'Voir ses wishlists'**
  String get homeCardSeeTheirWishlists;

  /// No description provided for @homeCardAfterPartyBirthdayOverline.
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =1{Ton anniversaire, c\'était hier} other{Ton anniversaire, c\'était il y a {days} jours}}'**
  String homeCardAfterPartyBirthdayOverline(int days);

  /// No description provided for @homeCardAfterPartyChristmasOverline.
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =1{Noël, c\'était hier} other{Noël, c\'était il y a {days} jours}}'**
  String homeCardAfterPartyChristmasOverline(int days);

  /// No description provided for @homeCardAfterPartyChristmasTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le Père Noël est passé ?'**
  String get homeCardAfterPartyChristmasTitle;

  /// No description provided for @homeCardAfterPartyBirthdayTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tu as été gâté ?'**
  String get homeCardAfterPartyBirthdayTitle;

  /// No description provided for @homeCardAfterPartyAction.
  ///
  /// In fr, this message translates to:
  /// **'Cocher ce que j\'ai reçu'**
  String get homeCardAfterPartyAction;

  /// No description provided for @homeCardAfterPartyNoList.
  ///
  /// In fr, this message translates to:
  /// **'Ouvre la bonne liste ci-dessous pour cocher ce que tu as reçu.'**
  String get homeCardAfterPartyNoList;

  /// No description provided for @homeCardBookedReminderBirthdayOverline.
  ///
  /// In fr, this message translates to:
  /// **'Rappel · {pseudo} fête son anniversaire {days, plural, =0{aujourd\'hui} =1{demain} other{dans {days} jours}}'**
  String homeCardBookedReminderBirthdayOverline(String pseudo, int days);

  /// No description provided for @homeCardBookedReminderChristmasOverline.
  ///
  /// In fr, this message translates to:
  /// **'Rappel · {days, plural, =0{c\'est Noël aujourd\'hui} =1{Noël demain} other{Noël dans {days} jours}}'**
  String homeCardBookedReminderChristmasOverline(int days);

  /// No description provided for @homeCardBookedReminderTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tu as réservé {wish}'**
  String homeCardBookedReminderTitle(String wish);

  /// No description provided for @homeCardSeeTheWish.
  ///
  /// In fr, this message translates to:
  /// **'Voir le wish'**
  String get homeCardSeeTheWish;

  /// No description provided for @homeCardRemovedOverline.
  ///
  /// In fr, this message translates to:
  /// **'Changement chez {pseudo}'**
  String homeCardRemovedOverline(String pseudo);

  /// No description provided for @homeCardRemovedOverlineNoPseudo.
  ///
  /// In fr, this message translates to:
  /// **'Changement dans une wishlist'**
  String get homeCardRemovedOverlineNoPseudo;

  /// No description provided for @homeCardRemovedTitle.
  ///
  /// In fr, this message translates to:
  /// **'{pseudo} a retiré {wish} que tu avais réservé'**
  String homeCardRemovedTitle(String pseudo, String wish);

  /// No description provided for @homeCardRemovedTitleNoPseudo.
  ///
  /// In fr, this message translates to:
  /// **'Un wish que tu avais réservé a été retiré'**
  String get homeCardRemovedTitleNoPseudo;

  /// No description provided for @homeCardRemovedBody.
  ///
  /// In fr, this message translates to:
  /// **'Si tu l\'as déjà acheté, tu peux toujours l\'offrir. Sinon, sa liste a d\'autres idées.'**
  String get homeCardRemovedBody;

  /// No description provided for @homeCardRemovedBodyNoList.
  ///
  /// In fr, this message translates to:
  /// **'Si tu l\'as déjà acheté, tu peux toujours l\'offrir.'**
  String get homeCardRemovedBodyNoList;

  /// No description provided for @homeCardAcceptedTitle.
  ///
  /// In fr, this message translates to:
  /// **'{pseudo} a accepté ta demande'**
  String homeCardAcceptedTitle(String pseudo);

  /// No description provided for @homeCardChristmasOverline.
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =0{C\'est le grand jour} =1{Noël demain} other{Noël dans {days} jours}}'**
  String homeCardChristmasOverline(int days);

  /// No description provided for @homeCardChristmasListTitle.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Ta liste « {name} » est vide} =1{Ta liste « {name} » a 1 wish} other{Ta liste « {name} » a {count} wishs}}'**
  String homeCardChristmasListTitle(String name, int count);

  /// No description provided for @homeCardChristmasListTitleNoCount.
  ///
  /// In fr, this message translates to:
  /// **'Ta liste « {name} »'**
  String homeCardChristmasListTitleNoCount(String name);

  /// No description provided for @homeCardChristmasListAction.
  ///
  /// In fr, this message translates to:
  /// **'Compléter'**
  String get homeCardChristmasListAction;

  /// No description provided for @homeCardChristmasNoListTitle.
  ///
  /// In fr, this message translates to:
  /// **'Noël approche'**
  String get homeCardChristmasNoListTitle;

  /// No description provided for @homeCardChristmasNoListAction.
  ///
  /// In fr, this message translates to:
  /// **'Créer ma liste de Noël'**
  String get homeCardChristmasNoListAction;

  /// No description provided for @homeCardChristmasDayTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le Père Noël a lu ta liste ?'**
  String get homeCardChristmasDayTitle;

  /// No description provided for @homeCardChristmasDayAction.
  ///
  /// In fr, this message translates to:
  /// **'Voir ma liste'**
  String get homeCardChristmasDayAction;

  /// No description provided for @homeCardOnboardingStep.
  ///
  /// In fr, this message translates to:
  /// **'Étape {step} sur {total}'**
  String homeCardOnboardingStep(int step, int total);

  /// No description provided for @homeCardOnboardingWishlistTitle.
  ///
  /// In fr, this message translates to:
  /// **'Crée ta première wishlist'**
  String get homeCardOnboardingWishlistTitle;

  /// No description provided for @homeCardOnboardingWishlistAction.
  ///
  /// In fr, this message translates to:
  /// **'Créer une wishlist'**
  String get homeCardOnboardingWishlistAction;

  /// No description provided for @homeCardOnboardingFriendTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute un ami'**
  String get homeCardOnboardingFriendTitle;

  /// No description provided for @homeCardOnboardingFriendAction.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un ami'**
  String get homeCardOnboardingFriendAction;

  /// No description provided for @homeCardOnboardingBirthdayTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute ton anniversaire'**
  String get homeCardOnboardingBirthdayTitle;

  /// No description provided for @homeCardOnboardingBirthdayAction.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get homeCardOnboardingBirthdayAction;

  /// No description provided for @homeCardOnboardingPhotoTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mets une photo'**
  String get homeCardOnboardingPhotoTitle;

  /// No description provided for @homeCardOnboardingPhotoAction.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une photo'**
  String get homeCardOnboardingPhotoAction;

  /// No description provided for @homeCardStaleOverline.
  ///
  /// In fr, this message translates to:
  /// **'Pas touchée depuis {months, plural, =0{0 mois} =1{1 mois} other{{months} mois}}'**
  String homeCardStaleOverline(int months);

  /// No description provided for @homeCardStaleTitle.
  ///
  /// In fr, this message translates to:
  /// **'« {name} » est toujours à jour ?'**
  String homeCardStaleTitle(String name);

  /// No description provided for @homeCardStaleConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Oui, c\'est bon'**
  String get homeCardStaleConfirm;

  /// No description provided for @homeCardStaleReview.
  ///
  /// In fr, this message translates to:
  /// **'La revoir'**
  String get homeCardStaleReview;

  /// No description provided for @homeCardYearRecapOverline.
  ///
  /// In fr, this message translates to:
  /// **'Ton année Wishy {year}'**
  String homeCardYearRecapOverline(String year);

  /// No description provided for @homeCardYearRecapTitle.
  ///
  /// In fr, this message translates to:
  /// **'{received}, {offered}'**
  String homeCardYearRecapTitle(String received, String offered);

  /// No description provided for @homeCardYearRecapOffered.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 offert} =1{1 offert} other{{count} offerts}}'**
  String homeCardYearRecapOffered(int count);

  /// No description provided for @homeCardYearRecapAwaited.
  ///
  /// In fr, this message translates to:
  /// **'Et {wish} qui t\'attendait depuis {year}'**
  String homeCardYearRecapAwaited(String wish, String year);

  /// No description provided for @homeCardYearRecapAction.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir'**
  String get homeCardYearRecapAction;

  /// No description provided for @yearRecapScreenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ton année Wishy {year}'**
  String yearRecapScreenTitle(String year);

  /// No description provided for @yearRecapReceived.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 wish reçu} =1{1 wish reçu} other{{count} wishs reçus}}'**
  String yearRecapReceived(int count);

  /// No description provided for @yearRecapOffered.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 wish offert} =1{1 wish offert} other{{count} wishs offerts}}'**
  String yearRecapOffered(int count);

  /// No description provided for @yearRecapLongestAwaited.
  ///
  /// In fr, this message translates to:
  /// **'Le plus attendu : {wish}, sur ta liste depuis {date}'**
  String yearRecapLongestAwaited(String wish, String date);

  /// No description provided for @yearRecapMostGifted.
  ///
  /// In fr, this message translates to:
  /// **'Ton ami le plus gâté : {pseudo}'**
  String yearRecapMostGifted(String pseudo);

  /// No description provided for @yearRecapBack.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get yearRecapBack;

  /// No description provided for @yearRecapProfileIntro.
  ///
  /// In fr, this message translates to:
  /// **'Cette année, j\'étais'**
  String get yearRecapProfileIntro;

  /// No description provided for @yearRecapShareButton.
  ///
  /// In fr, this message translates to:
  /// **'Partager mon année'**
  String get yearRecapShareButton;

  /// No description provided for @yearRecapShareImageHeader.
  ///
  /// In fr, this message translates to:
  /// **'Mon année {year}'**
  String yearRecapShareImageHeader(String year);

  /// No description provided for @yearRecapShareFooter.
  ///
  /// In fr, this message translates to:
  /// **'Et toi, t\'es qui ?'**
  String get yearRecapShareFooter;

  /// No description provided for @yearRecapShareText.
  ///
  /// In fr, this message translates to:
  /// **'Mon année Wishy {year} · wishy-app.fr'**
  String yearRecapShareText(String year);

  /// No description provided for @yearRecapProfilePatientTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le marathonien / La marathonienne'**
  String get yearRecapProfilePatientTitle;

  /// No description provided for @yearRecapProfilePatientTagline.
  ///
  /// In fr, this message translates to:
  /// **'Je l\'ai voulu. J\'ai attendu. Je l\'ai eu.'**
  String get yearRecapProfilePatientTagline;

  /// No description provided for @yearRecapProfilePereNoelDiscretTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le Père Noël / La Mère Noël'**
  String get yearRecapProfilePereNoelDiscretTitle;

  /// No description provided for @yearRecapProfilePereNoelDiscretTagline.
  ///
  /// In fr, this message translates to:
  /// **'Personne ne sait que c\'était moi.'**
  String get yearRecapProfilePereNoelDiscretTagline;

  /// No description provided for @yearRecapProfileGateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le gâté / La gâtée'**
  String get yearRecapProfileGateTitle;

  /// No description provided for @yearRecapProfileGateTagline.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai été très sage. Enfin, je crois.'**
  String get yearRecapProfileGateTagline;

  /// No description provided for @yearRecapProfileEquilibristeTitle.
  ///
  /// In fr, this message translates to:
  /// **'L\'équilibriste'**
  String get yearRecapProfileEquilibristeTitle;

  /// No description provided for @yearRecapProfileEquilibristeTagline.
  ///
  /// In fr, this message translates to:
  /// **'Donnant, donnant.'**
  String get yearRecapProfileEquilibristeTagline;

  /// No description provided for @yearRecapProfileReveurTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le rêveur / La rêveuse'**
  String get yearRecapProfileReveurTitle;

  /// No description provided for @yearRecapProfileReveurTagline.
  ///
  /// In fr, this message translates to:
  /// **'Rêver, c\'est gratuit.'**
  String get yearRecapProfileReveurTagline;

  /// No description provided for @yearRecapProfileRassembleurTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le rassembleur / La rassembleuse'**
  String get yearRecapProfileRassembleurTitle;

  /// No description provided for @yearRecapProfileRassembleurTagline.
  ///
  /// In fr, this message translates to:
  /// **'Plus on est de fous, plus on offre.'**
  String get yearRecapProfileRassembleurTagline;

  /// No description provided for @yearRecapProfileAmiFideleTitle.
  ///
  /// In fr, this message translates to:
  /// **'L\'ami fidèle / L\'amie fidèle'**
  String get yearRecapProfileAmiFideleTitle;

  /// No description provided for @yearRecapProfileAmiFideleTagline.
  ///
  /// In fr, this message translates to:
  /// **'Cette personne se reconnaîtra.'**
  String get yearRecapProfileAmiFideleTagline;

  /// No description provided for @yearRecapProfileDernierMomentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le roi / La reine du dernier moment'**
  String get yearRecapProfileDernierMomentTitle;

  /// No description provided for @yearRecapProfileDernierMomentTagline.
  ///
  /// In fr, this message translates to:
  /// **'Je travaille mieux sous pression.'**
  String get yearRecapProfileDernierMomentTagline;

  /// No description provided for @yearRecapProfileOrganiseTitle.
  ///
  /// In fr, this message translates to:
  /// **'L\'organisé / L\'organisée'**
  String get yearRecapProfileOrganiseTitle;

  /// No description provided for @yearRecapProfileOrganiseTagline.
  ///
  /// In fr, this message translates to:
  /// **'Papier cadeau à peine déchiré, liste déjà à jour.'**
  String get yearRecapProfileOrganiseTagline;

  /// No description provided for @yearRecapProfileMinimalisteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le minimaliste / La minimaliste'**
  String get yearRecapProfileMinimalisteTitle;

  /// No description provided for @yearRecapProfileMinimalisteTagline.
  ///
  /// In fr, this message translates to:
  /// **'Peu, mais bien.'**
  String get yearRecapProfileMinimalisteTagline;

  /// No description provided for @yearRecapReceivedShort.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 reçu} =1{1 reçu} other{{count} reçus}}'**
  String yearRecapReceivedShort(int count);

  /// No description provided for @yearRecapStatPatient.
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =0{0 jour} =1{1 jour} other{{days} jours}} pour {wish}'**
  String yearRecapStatPatient(int days, String wish);

  /// Figure of the patient profile on the share image: it never names the wish
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =0{0 jour d\'attente} =1{1 jour d\'attente} other{{days} jours d\'attente}}'**
  String yearRecapStatPatientShare(int days);

  /// No description provided for @yearRecapStatOfferedReceived.
  ///
  /// In fr, this message translates to:
  /// **'{offered}, {received}'**
  String yearRecapStatOfferedReceived(String offered, String received);

  /// No description provided for @yearRecapStatReveur.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 wish ajouté} =1{1 wish ajouté} other{{count} wishs ajoutés}}'**
  String yearRecapStatReveur(int count);

  /// No description provided for @yearRecapStatRassembleur.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 nouvel ami} =1{1 nouvel ami} other{{count} nouveaux amis}}'**
  String yearRecapStatRassembleur(int count);

  /// No description provided for @yearRecapStatAmiFidele.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 cadeau pour la même personne} =1{1 cadeau pour la même personne} other{{count} cadeaux pour la même personne}}'**
  String yearRecapStatAmiFidele(int count);

  /// No description provided for @yearRecapStatDernierMoment.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 cadeau réservé au dernier moment} =1{1 cadeau réservé au dernier moment} other{{count} cadeaux réservés au dernier moment}}'**
  String yearRecapStatDernierMoment(int count);

  /// No description provided for @yearRecapStatOrganise.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 wish coché le jour J} =1{1 wish coché le jour J} other{{count} wishs cochés le jour J}}'**
  String yearRecapStatOrganise(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
