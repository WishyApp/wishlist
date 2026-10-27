// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Wishy';

  @override
  String get emailField => 'Email';

  @override
  String get validEmailError => 'Please enter a valid email address';

  @override
  String get passwordField => 'Password';

  @override
  String get passwordRequirementMinLength => 'At least 8 characters';

  @override
  String get passwordRequirementUppercase => 'At least one uppercase letter';

  @override
  String get passwordRequirementLowercase => 'At least one lowercase letter';

  @override
  String get passwordRequirementNumber => 'At least one number';

  @override
  String get passwordRequirementSpecialChar => 'At least one special character';

  @override
  String get passwordSecurityError =>
      'Password does not meet all security requirements';

  @override
  String get signIn => 'Sign in';

  @override
  String get signUp => 'Sign up';

  @override
  String get dontHaveAccount => 'Don\'t have an account ?\nCreate one !';

  @override
  String get haveAccount => 'Already have an account ?\nSign in !';

  @override
  String get invalidLoginCredentials => 'Invalid login credentials';

  @override
  String get userAlreadyRegistered => 'This email is already registered';

  @override
  String get genericError => 'An error occurred, please try again!';

  @override
  String get inputTooLong => 'The input is too long.';

  @override
  String get wishOverbooked =>
      'This wish has just been booked by someone else. Refresh and try again.';

  @override
  String get wishQuantityBelowBooked =>
      'You can\'t lower the quantity: part of this wish is already booked.';

  @override
  String get networkError =>
      'Connection problem. Check your network and try again.';

  @override
  String get networkErrorTitle => 'Connection problem';

  @override
  String get networkErrorDescription =>
      'Your internet connection seems to be down or too slow. Check your Wi-Fi or mobile data, then try again.';

  @override
  String get loadingErrorTitle => 'This page couldn\'t be loaded';

  @override
  String get loadingErrorDescription =>
      'The problem is probably on our side. Try again in a few moments.';

  @override
  String get retryButton => 'Try again';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get updateRequiredDescription =>
      'This version of Wishy is no longer supported. Update the app to keep going.';

  @override
  String get updateRequiredNoLinkIosDescription =>
      'This version of Wishy is no longer supported. Update the app from TestFlight to keep going.';

  @override
  String get updateRequiredNoLinkAndroidDescription =>
      'This version of Wishy is no longer supported. Update the app from the Play Store to keep going.';

  @override
  String get updateAvailableTitle => 'New version available';

  @override
  String get updateAvailableMessage =>
      'Update Wishy to get the latest improvements.';

  @override
  String get updateAvailableNoLinkIosMessage =>
      'Update Wishy from TestFlight to get the latest improvements.';

  @override
  String get updateAvailableNoLinkAndroidMessage =>
      'Update Wishy from the Play Store to get the latest improvements.';

  @override
  String get updateButton => 'Update';

  @override
  String get updateLaterButton => 'Later';

  @override
  String get pseudoField => 'Pseudo';

  @override
  String get validPseudoError => 'Pseudo cannot be empty';

  @override
  String get pseudoAlreadyExists => 'This pseudo is already used';

  @override
  String get savePseudo => 'Save';

  @override
  String get pseudoStepTitle => 'Pick your pseudo';

  @override
  String get pseudoStepExplanation =>
      'It\'s the name your friends will see in Wishy.';

  @override
  String get bookedWishesScreenTitle => 'Bookings';

  @override
  String get bookedWishesEmptyTitle => 'No bookings';

  @override
  String get bookedWishesEmptyCallToAction =>
      'Explore your friends\' wishlists';

  @override
  String get settingsScreenTitle => 'Settings';

  @override
  String get settingsScreenEmail => 'Email';

  @override
  String get settingsScreenEmailModify => 'Modify';

  @override
  String get settingsScreenDisconnect => 'Disconnect';

  @override
  String get settingsScreenDisconnectDialogTitle => 'Disconnect';

  @override
  String get settingsScreenDisconnectDialogExplanation =>
      'Are you sure you want to disconnect ?';

  @override
  String get settingsScreenPasswordModify => 'Change my password';

  @override
  String get settingsScreenPseudoModify => 'Change my pseudo';

  @override
  String get changePasswordScreenTitle => 'Password';

  @override
  String get oldPasswordField => 'Old password';

  @override
  String get newPasswordField => 'New password';

  @override
  String get confirmNewPasswordField => 'Confirm new password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get oldPasswordIncorrect => 'Incorrect old password.';

  @override
  String get changePasswordConfirm => 'Change';

  @override
  String get newPasswordShouldBeDifferent =>
      'New password should be different from the old one.';

  @override
  String get passwordTooWeak =>
      'This password is too weak, please choose another one.';

  @override
  String get reauthenticationNeeded =>
      'Your session has expired, please start again.';

  @override
  String get changePseudoScreenTitle => 'Pseudo';

  @override
  String get newPseudoField => 'New pseudo';

  @override
  String get changePseudoConfirm => 'Change';

  @override
  String get changePseudoSuccess => 'Pseudo changed successfully!';

  @override
  String get settingsScreenBirthday => 'My birthday';

  @override
  String get settingsScreenBirthdayNotSet => 'Not set';

  @override
  String get changeBirthdayScreenTitle => 'Birthday';

  @override
  String get changeBirthdayExplanation => 'Only your friends will see it.';

  @override
  String get changeBirthdayConfirm => 'Save';

  @override
  String get changeBirthdayRemove => 'Remove my birthday';

  @override
  String get changeBirthdaySuccess => 'Birthday saved!';

  @override
  String get changeBirthdayRemoved => 'Birthday removed!';

  @override
  String get birthdayStepTitle => 'When is your birthday?';

  @override
  String get birthdayStepExplanation => 'Only your friends will see it.';

  @override
  String get birthdayStepLater => 'Later';

  @override
  String friendBirthdayBadge(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'in $days d',
      one: 'tomorrow',
      zero: 'today',
    );
    return '$_temp0';
  }

  @override
  String friendBirthdayWithCountdown(String date, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'in $days days',
      one: 'tomorrow',
      zero: 'today!',
    );
    return '$date · $_temp0';
  }

  @override
  String get changePasswordSuccess => 'Password changed successfully!';

  @override
  String get settingsScreenDeleteAccount => 'Delete my account';

  @override
  String get settingsScreenDeleteAccountDialogTitle => 'Delete my account';

  @override
  String get settingsScreenDeleteAccountDialogExplanation =>
      'Are you sure you want to delete your account? This action is irreversible and all your data will be permanently deleted.';

  @override
  String get deleteAccountSuccess => 'Account deleted successfully!';

  @override
  String get confirmDialogConfirmButtonLabel => 'OK';

  @override
  String get noWishlist => 'No wishlist';

  @override
  String get createButton => 'Create';

  @override
  String get createWishlist => 'Create a wishlist';

  @override
  String get name => 'Name';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get closeDialog => 'Dismiss the contextual window';

  @override
  String get fiendsScreenTitle => 'Friends';

  @override
  String get noFriend => 'No friend';

  @override
  String get addButton => 'Add';

  @override
  String get emailOrPseudoHint => 'Email or pseudo';

  @override
  String get noUserFound => 'No user found';

  @override
  String get friendDetailsRemove => 'Remove';

  @override
  String get removeFriendConfirmation =>
      'Are you sure you want to remove this friend?';

  @override
  String get removeFriendSuccess => 'Friend removed successfully!';

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
  String get friendDetailsMutualFriendsTitle => 'Mutual friends';

  @override
  String get friendDetailsNoMutualFriends => 'No mutual friends';

  @override
  String get seeAll => 'See all';

  @override
  String get hide => 'Hide';

  @override
  String get friendDetailsWishlistsTitle => 'Public wishlists';

  @override
  String get wishlistsScreenTitle => 'Wishlists';

  @override
  String get wishlistStatusPending => 'Pending';

  @override
  String get wishlistStatusBooked => 'Booked';

  @override
  String get wishlistSearchHint => 'Search for a wish...';

  @override
  String get bookedWishesSearchHint => 'By wish or pseudo...';

  @override
  String get wishlistNoWish => 'No wish';

  @override
  String get wishlistNoWishBooked => 'No wish booked';

  @override
  String get wishlistNoWishBookedDisplayed =>
      'You chose not to display booked wishes';

  @override
  String get wishlistAddWish => 'Add a wish';

  @override
  String get createWishBottomSheetTitle => 'Create a wish';

  @override
  String get createWishSuccess => 'Wish created successfully!';

  @override
  String get editWishBottomSheetTitle => 'Edit a wish';

  @override
  String get deleteWish => 'Delete wish';

  @override
  String get deleteWishConfirmationMessage =>
      'Are you sure you want to delete this wish?';

  @override
  String get deleteWishSuccess => 'Wish deleted successfully!';

  @override
  String get editButton => 'Edit';

  @override
  String get wishNameLabel => 'Name';

  @override
  String get wishPriceLabel => 'Price';

  @override
  String get wishQuantityLabel => 'Quantity';

  @override
  String get wishLinkLabel => 'Link';

  @override
  String get wishDescriptionLabel => 'Description';

  @override
  String get wishImageLabel => 'Wish image';

  @override
  String get uploadImage => 'Upload Image';

  @override
  String get wishNameError => 'Wish name is required';

  @override
  String get notNullError => 'This field is required';

  @override
  String get invalidNumber => 'Invalid number';

  @override
  String numberRangeError(Object max, Object min) {
    return 'Enter a number between $min and $max';
  }

  @override
  String get openLink => 'Open link';

  @override
  String get paste => 'Paste';

  @override
  String get linkNotValid => 'The link is not valid!';

  @override
  String get iWantToGiveIt => 'I want to give it';

  @override
  String get cancelBooking => 'Cancel my booking';

  @override
  String get modifyBooking => 'Modify my booking';

  @override
  String get modifyCompletedQuantity => 'Modify completed quantity';

  @override
  String get cancelBookingDialogTitle => 'Cancel booking';

  @override
  String get cancelBookingDialogExplanation =>
      'Are you sure you want to cancel this booking?';

  @override
  String get noDescription => 'No description';

  @override
  String get private => 'Private';

  @override
  String get public => 'Public';

  @override
  String get save => 'Save';

  @override
  String get updateSuccess => 'Update successfully completed!';

  @override
  String get deleteWishlist => 'Delete my wishlist';

  @override
  String get deleteWishlistConfirmation =>
      'Are you sure you want to delete this wishlist?';

  @override
  String get deleteWishlistWishesWarning =>
      'Uncompleted wishes will be deleted. Completed wishes will remain in your history.';

  @override
  String get deleteWishlistSuccess => 'Wishlist successfully deleted!';

  @override
  String get wishlistDeleted => 'This wishlist has been deleted';

  @override
  String get wishUnavailable => 'This wish is no longer available';

  @override
  String get sortWishs => 'Sort wishes';

  @override
  String get sortByFavorite => 'By favorites';

  @override
  String get sortByAlphabetical => 'By alphabetical order';

  @override
  String get sortByPrice => 'By price';

  @override
  String get sortByDate => 'By creation date';

  @override
  String get sortByCompletedAt => 'By completion date';

  @override
  String get sortByBookingCount => 'By booking count';

  @override
  String get selectQuantityToGive => 'How much would you like to offer?';

  @override
  String get selectQuantityToComplete => 'How many did you complete?';

  @override
  String get wishReservedSuccess => 'Wish reserved successfully!';

  @override
  String quantityCannotBeLowerThanBooked(Object bookedQuantity) {
    return 'Quantity cannot be lower than $bookedQuantity (already booked quantity)';
  }

  @override
  String get deleteSelectedWishes => 'Delete wishes';

  @override
  String get deleteSelectedWishConfirmation =>
      'Are you sure you want to delete this wish?';

  @override
  String deleteSelectedWishesConfirmation(int count) {
    return 'Are you sure you want to delete these $count wishes?';
  }

  @override
  String wishesDeleted(int count) {
    return '$count wishes deleted successfully!';
  }

  @override
  String get moveWishes => 'Move wishes';

  @override
  String get moveButton => 'Move';

  @override
  String get reintegrateWish => 'Restore a wish';

  @override
  String get reintegrateWishExplanation =>
      'The wishlist this wish came from has been deleted. Select the wishlist in which you want to restore it:';

  @override
  String get reintegrateButton => 'Restore';

  @override
  String get selectWishlist => 'Select a wishlist';

  @override
  String selectDestinationWishlist(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'these $count wishes',
      one: 'this wish',
    );
    return 'Select the wishlist where you want to move $_temp0:';
  }

  @override
  String get noOtherWishlistsAvailable => 'No other wishlists available';

  @override
  String get closeButton => 'Close';

  @override
  String get errorLoadingWishlists => 'Error loading wishlists';

  @override
  String wishesMoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wishes moved successfully!',
      one: 'Wish moved successfully!',
    );
    return '$_temp0';
  }

  @override
  String get avatarOptions => 'Avatar modification';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get imageOptions => 'Image upload';

  @override
  String get cropImageTitle => 'Crop image';

  @override
  String get cropImageCancel => 'Cancel';

  @override
  String get cropImageValidate => 'Confirm';

  @override
  String get removeImage => 'Remove image';

  @override
  String get removeImageConfirmation =>
      'Are you sure you want to remove this image?';

  @override
  String get avatarLoadError => 'Error loading image';

  @override
  String get forgotPasswordButton => 'Forgot password?';

  @override
  String get forgotPasswordTitle => 'Forgot password';

  @override
  String get forgotPasswordDescription =>
      'Please enter your email address to receive the password reset link.';

  @override
  String get forgotPasswordSendButton => 'Send';

  @override
  String get forgotPasswordEmailSent => 'A password reset email has been sent!';

  @override
  String get resetPasswordTitle => 'Reset password';

  @override
  String get resetPasswordDescription => 'Enter your new password.';

  @override
  String get resetPasswordConfirm => 'Reset';

  @override
  String get resetPasswordSuccess =>
      'Password reset successfully! Please sign in with your new password.';

  @override
  String get resetPasswordLinkExpired =>
      'The reset link has expired. Please request a new one.';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsTermsOfUse => 'Terms of use';

  @override
  String get settingsPrivacyPolicy => 'Privacy policy';

  @override
  String get completedWishesScreenTitle => 'Completed wishes';

  @override
  String get completedWishesEmptyTitle => 'No completed wishes';

  @override
  String get markWishAsCompleted => 'Mark as completed';

  @override
  String get unmarkWishAsCompleted => 'Remove from completed';

  @override
  String get settingsCompletedWishes => 'My completed wishes';

  @override
  String get unmarkWishConfirmTitle => 'Remove from completed';

  @override
  String unmarkWishConfirmMessage(String wishlistName) {
    return 'This wish will become visible again in the wishlist \"$wishlistName\".';
  }

  @override
  String get unmarkWishArchivedConfirmMessage =>
      'Choose a wishlist in which to restore this wish.';

  @override
  String get deletedWishlist => 'Deleted wishlist';

  @override
  String get friendCompletedWishesTitle => 'Completed wishes';

  @override
  String get completeSelectedWishes => 'Complete';

  @override
  String get seeAllCompletedWishes => 'See all';

  @override
  String get relativeDateToday => 'Today';

  @override
  String get relativeDateYesterday => 'Yesterday';

  @override
  String relativeDateDaysAgo(int count) {
    return '$count days ago';
  }

  @override
  String relativeDateWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks ago',
      one: '1 week ago',
    );
    return '$_temp0';
  }

  @override
  String get bookedWishesTabToGive => 'To give';

  @override
  String get bookedWishesTabGiven => 'Given';

  @override
  String bookedWishesToGiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count to give',
      one: '1 to give',
    );
    return '$_temp0';
  }

  @override
  String bookedWishesGivenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count given',
      one: '1 given',
    );
    return '$_temp0';
  }

  @override
  String get bookedWishesNothingToGive =>
      'Nothing left to give: everything was received';

  @override
  String get bookedWishesNothingGiven =>
      'Booked wishes your friends received will show up here';

  @override
  String bookedWishReceivedOn(String date) {
    return 'Received on $date';
  }

  @override
  String wishlistSelectionCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'selected',
    );
    return '$_temp0';
  }

  @override
  String wishlistSelectionCount(int count) {
    return '$count selected';
  }

  @override
  String get wishlistSelectAll => 'Select all';

  @override
  String get wishlistExitSelection => 'Exit selection';

  @override
  String get wishlistSelectionComplete => 'Complete';

  @override
  String get wishlistSelectionMove => 'Move';

  @override
  String get wishlistSelectionDelete => 'Delete';

  @override
  String get wishlistSettingsTitle => 'Settings';

  @override
  String get wishlistNameLabel => 'Wishlist name';

  @override
  String get wishlistNameRequired => 'Give your wishlist a name';

  @override
  String get wishlistColorLabel => 'Color';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorPurple => 'Purple';

  @override
  String get colorYellow => 'Yellow';

  @override
  String get colorGreen => 'Green';

  @override
  String get wishlistVisibilityLabel => 'Visibility';

  @override
  String get wishlistPublicDescription =>
      'Your loved ones can see it and you can share it with a link.';

  @override
  String get wishlistPrivateDescription =>
      'Only you can see it. Sharing with a link is turned off.';

  @override
  String get seeBookedWishesLabel => 'See what is booked';

  @override
  String get seeBookedWishesOnDescription =>
      'You can see which wishes have been booked. Goodbye surprise!';

  @override
  String get seeBookedWishesOffDescription =>
      'You don\'t know what has been booked: the surprise stays whole.';

  @override
  String get deleteButton => 'Delete';

  @override
  String get unsavedChangesTitle => 'Leave without saving?';

  @override
  String get unsavedChangesMessage => 'Your changes will be lost.';

  @override
  String get unsavedChangesLeave => 'Leave without saving';

  @override
  String get unsavedChangesKeepEditing => 'Keep editing';

  @override
  String get wishlistSettingsOwnerOnly =>
      'Only the owner of this wishlist can change its settings';
}
