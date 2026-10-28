// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Wishy';

  @override
  String get emailField => 'Email';

  @override
  String get validEmailError => 'Veuillez saisir une adresse e-mail valide';

  @override
  String get passwordField => 'Mot de passe';

  @override
  String get passwordRequirementMinLength => 'Au moins 8 caractères';

  @override
  String get passwordRequirementUppercase => 'Au moins une majuscule';

  @override
  String get passwordRequirementLowercase => 'Au moins une minuscule';

  @override
  String get passwordRequirementNumber => 'Au moins un chiffre';

  @override
  String get passwordRequirementSpecialChar => 'Au moins un caractère spécial';

  @override
  String get passwordSecurityError =>
      'Le mot de passe ne respecte pas tous les critères de sécurité';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signUp => 'S\'inscrire';

  @override
  String get dontHaveAccount => 'Vous n\'avez pas de compte ?\nCréez-en un !';

  @override
  String get haveAccount => 'Vous avez déjà un compte ?\nConnectez-vous !';

  @override
  String get invalidLoginCredentials => 'Identifiants de connexion invalides';

  @override
  String get userAlreadyRegistered => 'Cet email est déjà enregistré';

  @override
  String get genericError => 'Une erreur est survenue, veuillez réessayer.';

  @override
  String get inputTooLong => 'La saisie est trop longue.';

  @override
  String get wishOverbooked =>
      'Ce wish vient d\'être réservé par quelqu\'un d\'autre. Actualise et réessaie.';

  @override
  String get wishQuantityBelowBooked =>
      'Impossible de baisser la quantité : une partie de ce wish est déjà réservée.';

  @override
  String get networkError =>
      'Problème de connexion. Vérifie ton réseau puis réessaie.';

  @override
  String get networkErrorTitle => 'Problème de connexion';

  @override
  String get networkErrorDescription =>
      'Ta connexion internet semble absente ou trop lente. Vérifie ton Wi-Fi ou tes données mobiles, puis réessaie.';

  @override
  String get loadingErrorTitle => 'Impossible de charger cette page';

  @override
  String get loadingErrorDescription =>
      'Le problème vient sûrement de chez nous. Réessaie dans quelques instants.';

  @override
  String get retryButton => 'Réessayer';

  @override
  String get updateRequiredTitle => 'Mise à jour requise';

  @override
  String get updateRequiredDescription =>
      'Cette version de Wishy n\'est plus prise en charge. Mets l\'application à jour pour continuer.';

  @override
  String get updateRequiredNoLinkIosDescription =>
      'Cette version de Wishy n\'est plus prise en charge. Mets l\'application à jour depuis TestFlight pour continuer.';

  @override
  String get updateRequiredNoLinkAndroidDescription =>
      'Cette version de Wishy n\'est plus prise en charge. Mets l\'application à jour depuis le Play Store pour continuer.';

  @override
  String get updateAvailableTitle => 'Nouvelle version disponible';

  @override
  String get updateAvailableMessage =>
      'Mets Wishy à jour pour profiter des dernières nouveautés.';

  @override
  String get updateAvailableNoLinkIosMessage =>
      'Mets Wishy à jour depuis TestFlight pour profiter des dernières nouveautés.';

  @override
  String get updateAvailableNoLinkAndroidMessage =>
      'Mets Wishy à jour depuis le Play Store pour profiter des dernières nouveautés.';

  @override
  String get updateButton => 'Mettre à jour';

  @override
  String get updateLaterButton => 'Plus tard';

  @override
  String get pseudoField => 'Pseudo';

  @override
  String get validPseudoError => 'Le pseudo ne peut pas être vide';

  @override
  String get pseudoAlreadyExists => 'Ce pseudo est déjà utilisé';

  @override
  String get savePseudo => 'Enregistrer';

  @override
  String get pseudoStepTitle => 'Choisis ton pseudo';

  @override
  String get pseudoStepExplanation =>
      'C\'est le nom que tes amis verront dans Wishy.';

  @override
  String get bookedWishesScreenTitle => 'Réservations';

  @override
  String get bookedWishesEmptyTitle => 'Aucune réservation';

  @override
  String get bookedWishesEmptyCallToAction =>
      'Explorer les wishlists de vos amis';

  @override
  String get settingsScreenTitle => 'Paramètres';

  @override
  String get settingsScreenEmail => 'Email';

  @override
  String get settingsScreenEmailModify => 'Modifier';

  @override
  String get settingsScreenDisconnect => 'Se déconnecter';

  @override
  String get settingsScreenDisconnectDialogTitle => 'Se déconnecter';

  @override
  String get settingsScreenDisconnectDialogExplanation =>
      'Es-tu sûr de vouloir te déconnecter ?';

  @override
  String get settingsScreenPasswordModify => 'Modifier mon mot de passe';

  @override
  String get settingsScreenPseudoModify => 'Modifier mon pseudo';

  @override
  String get changePasswordScreenTitle => 'Mot de passe';

  @override
  String get oldPasswordField => 'Ancien mot de passe';

  @override
  String get newPasswordField => 'Nouveau mot de passe';

  @override
  String get confirmNewPasswordField => 'Confirmer le nouveau mot de passe';

  @override
  String get passwordsDoNotMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get oldPasswordIncorrect => 'Ancien mot de passe incorrect.';

  @override
  String get changePasswordConfirm => 'Modifier';

  @override
  String get newPasswordShouldBeDifferent =>
      'Le nouveau mot de passe doit être différent de l\'ancien.';

  @override
  String get passwordTooWeak =>
      'Le mot de passe est trop faible, choisissez-en un autre.';

  @override
  String get reauthenticationNeeded =>
      'Votre session a expiré, veuillez recommencer.';

  @override
  String get changePseudoScreenTitle => 'Pseudo';

  @override
  String get newPseudoField => 'Nouveau pseudo';

  @override
  String get changePseudoConfirm => 'Modifier';

  @override
  String get changePseudoSuccess => 'Pseudo modifié avec succès !';

  @override
  String get settingsScreenBirthday => 'Mon anniversaire';

  @override
  String get settingsScreenBirthdayNotSet => 'Non renseigné';

  @override
  String get changeBirthdayScreenTitle => 'Anniversaire';

  @override
  String get changeBirthdayExplanation => 'Seuls tes amis le verront.';

  @override
  String get changeBirthdayConfirm => 'Enregistrer';

  @override
  String get changeBirthdayRemove => 'Supprimer mon anniversaire';

  @override
  String get changeBirthdaySuccess => 'Anniversaire enregistré !';

  @override
  String get changeBirthdayRemoved => 'Anniversaire supprimé !';

  @override
  String get birthdayStepTitle => 'C\'est quand ton anniversaire ?';

  @override
  String get birthdayStepExplanation => 'Seuls tes amis le verront.';

  @override
  String get birthdayStepLater => 'Plus tard';

  @override
  String friendBirthdayBadge(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'dans $days j',
      one: 'demain',
      zero: 'aujourd\'hui',
    );
    return '$_temp0';
  }

  @override
  String friendBirthdayWithCountdown(String date, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'dans $days jours',
      one: 'demain',
      zero: 'aujourd\'hui !',
    );
    return '$date · $_temp0';
  }

  @override
  String get changePasswordSuccess => 'Mot de passe changé avec succès !';

  @override
  String get settingsScreenDeleteAccount => 'Supprimer mon compte';

  @override
  String get settingsScreenDeleteAccountDialogTitle => 'Supprimer mon compte';

  @override
  String get settingsScreenDeleteAccountDialogExplanation =>
      'Es-tu sûr de vouloir supprimer ton compte ? Cette action est irréversible et toutes tes données seront définitivement supprimées.';

  @override
  String get deleteAccountSuccess => 'Compte supprimé avec succès !';

  @override
  String get confirmDialogConfirmButtonLabel => 'OK';

  @override
  String get noWishlist => 'Aucune wishlist';

  @override
  String get createButton => 'Créer';

  @override
  String get createWishlist => 'Créer une wishlist';

  @override
  String get name => 'Nom';

  @override
  String get cancelButton => 'Annuler';

  @override
  String get closeDialog => 'Fermer la fenêtre contextuelle';

  @override
  String get fiendsScreenTitle => 'Amis';

  @override
  String get noFriend => 'Aucun ami';

  @override
  String get addButton => 'Ajouter';

  @override
  String get emailOrPseudoHint => 'Email ou pseudo';

  @override
  String get noUserFound => 'Aucun utilisateur trouvé';

  @override
  String get friendDetailsRemove => 'Supprimer';

  @override
  String get removeFriendConfirmation =>
      'Es-tu sûr de vouloir supprimer cet ami ?';

  @override
  String get removeFriendSuccess => 'Ami supprimé avec succès !';

  @override
  String numberOfWishlists(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wishlists',
      one: '1 wishlist',
      zero: '0 wishlist',
    );
    return '$_temp0';
  }

  @override
  String numberOfWishs(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wishs',
      one: '1 wish',
      zero: '0 wish',
    );
    return '$_temp0';
  }

  @override
  String get friendDetailsMutualFriendsTitle => 'Amis en commun';

  @override
  String get friendDetailsNoMutualFriends => 'Aucun ami en commun';

  @override
  String get seeAll => 'Voir plus';

  @override
  String get hide => 'Masquer';

  @override
  String get friendDetailsWishlistsTitle => 'Wishlists publiques';

  @override
  String get wishlistsScreenTitle => 'Wishlists';

  @override
  String get wishlistStatusPending => 'En attente';

  @override
  String get wishlistStatusBooked => 'Réservés';

  @override
  String get wishlistSearchHint => 'Rechercher un wish...';

  @override
  String get bookedWishesSearchHint => 'Par wish ou pseudo...';

  @override
  String get wishlistNoWish => 'Aucun wish';

  @override
  String get wishlistNoWishBooked => 'Aucun wish réservé';

  @override
  String get wishlistNoWishBookedDisplayed =>
      'Tu as choisi de ne pas afficher les wishs réservés';

  @override
  String get wishlistAddWish => 'Ajouter un wish';

  @override
  String get createWishBottomSheetTitle => 'Créer un wish';

  @override
  String get createWishSuccess => 'Wish créé avec succès !';

  @override
  String get editWishBottomSheetTitle => 'Modifier un wish';

  @override
  String get deleteWish => 'Supprimer le wish';

  @override
  String get deleteWishConfirmationMessage =>
      'Es-tu sûr de vouloir supprimer ce wish ?';

  @override
  String get deleteWishSuccess => 'Wish supprimé avec succès !';

  @override
  String get editButton => 'Modifier';

  @override
  String get wishNameLabel => 'Nom';

  @override
  String get wishPriceLabel => 'Prix';

  @override
  String get wishQuantityLabel => 'Quantité';

  @override
  String get wishLinkLabel => 'Lien';

  @override
  String get wishDescriptionLabel => 'Description';

  @override
  String get wishImageLabel => 'Image du wish';

  @override
  String get uploadImage => 'Ajouter une image';

  @override
  String get wishNameError => 'Le nom du wish est requis';

  @override
  String get notNullError => 'Ce champ est requis';

  @override
  String get invalidNumber => 'Nombre invalide';

  @override
  String numberRangeError(Object max, Object min) {
    return 'Saisis un nombre entre $min et $max';
  }

  @override
  String get openLink => 'Ouvrir le lien';

  @override
  String get paste => 'Coller';

  @override
  String get linkNotValid => 'Le lien n\'est pas valide !';

  @override
  String get iWantToGiveIt => 'Je veux l\'offrir';

  @override
  String get cancelBooking => 'Annuler ma réservation';

  @override
  String get modifyBooking => 'Modifier ma réservation';

  @override
  String get modifyCompletedQuantity => 'Modifier la quantité complétée';

  @override
  String get cancelBookingDialogTitle => 'Annuler la réservation';

  @override
  String get cancelBookingDialogExplanation =>
      'Es-tu sûr de vouloir annuler cette réservation ?';

  @override
  String get noDescription => 'Aucune description';

  @override
  String get save => 'Enregistrer';

  @override
  String get updateSuccess => 'Mise à jour effectuée avec succès !';

  @override
  String get deleteWishlist => 'Supprimer ma wishlist';

  @override
  String get deleteWishlistConfirmation =>
      'Es-tu sûr de vouloir supprimer cette wishlist ?';

  @override
  String get deleteWishlistWishesWarning =>
      'Les wishs non complétés seront supprimés. Les wishs complétés resteront dans ton historique.';

  @override
  String get deleteWishlistSuccess => 'Wishlist supprimée avec succès !';

  @override
  String get wishlistDeleted => 'Cette wishlist a été supprimée';

  @override
  String get wishUnavailable => 'Ce wish n\'est plus disponible';

  @override
  String get sortWishs => 'Trier les wishs';

  @override
  String get sortByFavorite => 'Par favoris';

  @override
  String get sortByAlphabetical => 'Par ordre alphabétique';

  @override
  String get sortByPrice => 'Par prix';

  @override
  String get sortByDate => 'Par date de création';

  @override
  String get sortByCompletedAt => 'Par date de complétion';

  @override
  String get sortByBookingCount => 'Par nombre de réservations';

  @override
  String get selectQuantityToGive => 'Quelle quantité souhaites-tu offrir ?';

  @override
  String get selectQuantityToComplete => 'Quelle quantité as-tu complétée ?';

  @override
  String get wishReservedSuccess => 'Wish réservé avec succès !';

  @override
  String quantityCannotBeLowerThanBooked(Object bookedQuantity) {
    return 'La quantité ne peut pas être inférieure à $bookedQuantity (quantité déjà réservée)';
  }

  @override
  String get deleteSelectedWishes => 'Supprimer les wishs';

  @override
  String get deleteSelectedWishConfirmation =>
      'Voulez-vous vraiment supprimer ce wish ?';

  @override
  String deleteSelectedWishesConfirmation(int count) {
    return 'Voulez-vous vraiment supprimer ces $count wishs ?';
  }

  @override
  String wishesDeleted(int count) {
    return '$count wishs supprimés avec succès !';
  }

  @override
  String get moveWishes => 'Déplacer des wishs';

  @override
  String get moveButton => 'Déplacer';

  @override
  String get reintegrateWish => 'Réintégrer un wish';

  @override
  String get reintegrateWishExplanation =>
      'La wishlist d\'origine de ce wish a été supprimée, sélectionne la wishlist vers laquelle tu veux le réintégrer :';

  @override
  String get reintegrateButton => 'Réintégrer';

  @override
  String get selectWishlist => 'Sélectionner une wishlist';

  @override
  String selectDestinationWishlist(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ces $count wishs',
      one: 'ce wish',
    );
    return 'Sélectionne la wishlist vers laquelle tu veux déplacer $_temp0 :';
  }

  @override
  String get noOtherWishlistsAvailable => 'Aucune autre wishlist disponible';

  @override
  String get closeButton => 'Fermer';

  @override
  String get errorLoadingWishlists => 'Erreur lors du chargement des wishlists';

  @override
  String wishesMoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wishs déplacés avec succès !',
      one: 'Wish déplacé avec succès !',
    );
    return '$_temp0';
  }

  @override
  String get avatarOptions => 'Modification de l\'avatar';

  @override
  String get chooseFromGallery => 'Choisir depuis la galerie';

  @override
  String get takePhoto => 'Prendre une photo';

  @override
  String get imageOptions => 'Ajout de l\'image';

  @override
  String get cropImageTitle => 'Recadrer l\'image';

  @override
  String get cropImageCancel => 'Annuler';

  @override
  String get cropImageValidate => 'Valider';

  @override
  String get removeImage => 'Supprimer l\'image';

  @override
  String get removeImageConfirmation =>
      'Es-tu sûr de vouloir supprimer cette image ?';

  @override
  String get avatarLoadError => 'Erreur lors du chargement de l\'image';

  @override
  String get forgotPasswordButton => 'Mot de passe oublié ?';

  @override
  String get forgotPasswordTitle => 'Mot de passe oublié';

  @override
  String get forgotPasswordDescription =>
      'Veuillez saisir votre adresse e-mail afin de recevoir le lien de réinitialisation de votre mot de passe.';

  @override
  String get forgotPasswordSendButton => 'Envoyer';

  @override
  String get forgotPasswordEmailSent =>
      'Un e-mail de réinitialisation a été envoyé !';

  @override
  String get resetPasswordTitle => 'Réinitialiser le mot de passe';

  @override
  String get resetPasswordDescription =>
      'Saisissez votre nouveau mot de passe.';

  @override
  String get resetPasswordConfirm => 'Réinitialiser';

  @override
  String get resetPasswordSuccess =>
      'Mot de passe réinitialisé avec succès ! Reconnectez-vous avec votre nouveau mot de passe.';

  @override
  String get resetPasswordLinkExpired =>
      'Le lien de réinitialisation a expiré. Veuillez en demander un nouveau.';

  @override
  String get settingsGeneral => 'Général';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get settingsTermsOfUse => 'Conditions d\'utilisation';

  @override
  String get settingsPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get completedWishesScreenTitle => 'Wishs complétés';

  @override
  String get completedWishesEmptyTitle => 'Aucun wish complété';

  @override
  String get markWishAsCompleted => 'Marquer comme complété';

  @override
  String get unmarkWishAsCompleted => 'Retirer des complétés';

  @override
  String get settingsCompletedWishes => 'Mes wishs complétés';

  @override
  String get unmarkWishConfirmTitle => 'Retirer des wishs complétés';

  @override
  String unmarkWishConfirmMessage(String wishlistName) {
    return 'Ce wish redeviendra visible dans la wishlist \"$wishlistName\".';
  }

  @override
  String get unmarkWishArchivedConfirmMessage =>
      'Choisis une wishlist dans laquelle remettre ce wish.';

  @override
  String get deletedWishlist => 'Wishlist supprimée';

  @override
  String get friendCompletedWishesTitle => 'Wishs complétés';

  @override
  String get completeSelectedWishes => 'Compléter';

  @override
  String get seeAllCompletedWishes => 'Tout voir';

  @override
  String get relativeDateToday => 'Aujourd\'hui';

  @override
  String get relativeDateYesterday => 'Hier';

  @override
  String relativeDateDaysAgo(int count) {
    return 'Il y a $count jours';
  }

  @override
  String relativeDateWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count semaines',
      one: 'Il y a 1 semaine',
    );
    return '$_temp0';
  }

  @override
  String get bookedWishesTabToGive => 'À offrir';

  @override
  String get bookedWishesTabGiven => 'Offerts';

  @override
  String bookedWishesToGiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count à offrir',
      one: '1 à offrir',
      zero: '0 à offrir',
    );
    return '$_temp0';
  }

  @override
  String bookedWishesGivenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offerts',
      one: '1 offert',
      zero: '0 offert',
    );
    return '$_temp0';
  }

  @override
  String get bookedWishesNothingToGive =>
      'Plus rien à offrir : tout a été reçu';

  @override
  String get bookedWishesNothingGiven =>
      'Les wishs réservés que tes amis ont reçus apparaîtront ici';

  @override
  String bookedWishReceivedOn(String date) {
    return 'Reçu le $date';
  }

  @override
  String wishlistSelectionCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sélectionnés',
      one: 'sélectionné',
      zero: 'sélectionné',
    );
    return '$_temp0';
  }

  @override
  String wishlistSelectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnés',
      one: '1 sélectionné',
      zero: '0 sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get wishlistSelectAll => 'Tout sélectionner';

  @override
  String get wishlistExitSelection => 'Quitter la sélection';

  @override
  String get wishlistSelectionComplete => 'Valider';

  @override
  String get wishlistSelectionMove => 'Déplacer';

  @override
  String get wishlistSelectionDelete => 'Supprimer';

  @override
  String get wishlistSettingsTitle => 'Paramètres';

  @override
  String get wishlistNameLabel => 'Nom de la wishlist';

  @override
  String get wishlistNameRequired => 'Donne un nom à ta wishlist';

  @override
  String get wishlistColorLabel => 'Couleur';

  @override
  String get colorBlue => 'Bleu';

  @override
  String get colorPurple => 'Violet';

  @override
  String get colorYellow => 'Jaune';

  @override
  String get colorGreen => 'Vert';

  @override
  String get publicWishlistLabel => 'Wishlist publique';

  @override
  String get wishlistPublicDescription =>
      'Tes proches peuvent la voir et tu peux la partager par lien.';

  @override
  String get wishlistPrivateDescription =>
      'Toi seul la vois. Le partage par lien est désactivé.';

  @override
  String get seeBookedWishesLabel => 'Voir ce qui est réservé';

  @override
  String get seeBookedWishesOnDescription =>
      'Tu vois quels wishs ont été réservés. Adieu la surprise !';

  @override
  String get seeBookedWishesOffDescription =>
      'Tu ne sais pas ce qui a été réservé : la surprise reste entière.';

  @override
  String get deleteButton => 'Supprimer';

  @override
  String get unsavedChangesTitle => 'Quitter sans enregistrer ?';

  @override
  String get unsavedChangesMessage => 'Tes modifications seront perdues.';

  @override
  String get unsavedChangesLeave => 'Quitter sans enregistrer';

  @override
  String get unsavedChangesKeepEditing => 'Continuer à modifier';

  @override
  String get wishlistSettingsOwnerOnly =>
      'Seul le propriétaire de cette wishlist peut modifier ses paramètres';
}
