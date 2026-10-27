import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_color_selector.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_settings_app_bar.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_settings_card.dart';
import 'package:wishlist/shared/infra/current_user_id_provider.dart';
import 'package:wishlist/shared/infra/repositories/wishlist/wishlist_streams_providers.dart';
import 'package:wishlist/shared/infra/wishlist_mutations_provider.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/theme/utils/get_wishlist_theme.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';
import 'package:wishlist/shared/utils/app_snackbar.dart';
import 'package:wishlist/shared/utils/retry_providers_extension.dart';
import 'package:wishlist/shared/widgets/app_switch.dart';
import 'package:wishlist/shared/widgets/dialogs/app_dialog.dart';
import 'package:wishlist/shared/widgets/error_page_with_back.dart';
import 'package:wishlist/shared/widgets/text_form_fields/app_text_field.dart';

/// Limite de la contrainte `wishlists_name_max_length` en base.
const wishlistNameMaxLength = 50;

class WishlistSettingsScreen extends ConsumerStatefulWidget {
  const WishlistSettingsScreen({
    super.key,
    required this.wishlistId,
  });

  final int wishlistId;

  @override
  ConsumerState<WishlistSettingsScreen> createState() =>
      _WishlistSettingsScreenState();
}

class _WishlistSettingsScreenState
    extends ConsumerState<WishlistSettingsScreen> {
  /// Dernière version reçue, pour garder le formulaire affiché pendant que
  /// l'utilisateur supprime la wishlist : le stream émet null avant que la
  /// suppression ne rende la main et ne quitte l'écran.
  Wishlist? _lastWishlist;

  /// Suppression lancée depuis cet écran. Reste vrai une fois la suppression
  /// finie : l'écran est encore affiché pendant l'animation du retour à
  /// l'accueil et ne doit pas y montrer « wishlist supprimée ».
  bool _isDeletingHere = false;

  void _onDeletingChanged({required bool isDeleting}) {
    if (mounted) {
      setState(() => _isDeletingHere = isDeleting);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = watchWishlistByIdProvider(widget.wishlistId);
    final wishlistAsync = ref.watch(provider);

    return wishlistAsync.when(
      // A failed refetch must not unmount the form and lose the user's edits
      skipError: wishlistAsync.hasValue,
      data: (wishlist) {
        if (wishlist != null) {
          _lastWishlist = wishlist;
        }
        final shownWishlist =
            wishlist ?? (_isDeletingHere ? _lastWishlist : null);
        if (shownWishlist == null) {
          return ErrorPageWithBack.unavailable(
            message: context.l10n.wishlistDeleted,
          );
        }
        // La route s'ouvre aussi par un lien profond : la wishlist publique
        // d'un autre ne doit pas montrer un formulaire voué à échouer. read et
        // pas watch, comme WishlistScreen : l'écran survit quelques frames à
        // la session, jusqu'à la redirection du routeur
        if (shownWishlist.idOwner != ref.read(currentUserIdProvider)) {
          return ErrorPageWithBack.unavailable(
            message: context.l10n.wishlistSettingsOwnerOnly,
          );
        }

        return _WishlistSettingsForm(
          wishlist: shownWishlist,
          onDeletingChanged: _onDeletingChanged,
        );
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => ErrorPageWithBack.failure(
        error: error,
        onRetry: () => ref.retryFailed([provider]),
        isRetrying: ref.isRetryingAny([provider]),
      ),
    );
  }
}

class _WishlistSettingsForm extends ConsumerStatefulWidget {
  const _WishlistSettingsForm({
    required this.wishlist,
    required this.onDeletingChanged,
  });

  /// Dernière version enregistrée de la wishlist, mise à jour en temps réel.
  final Wishlist wishlist;

  /// Appelé au début d'une suppression, puis si elle échoue.
  final void Function({required bool isDeleting}) onDeletingChanged;

  @override
  ConsumerState<_WishlistSettingsForm> createState() =>
      _WishlistSettingsFormState();
}

class _WishlistSettingsFormState extends ConsumerState<_WishlistSettingsForm> {
  late final TextEditingController _nameController;
  late Color _color;
  late WishlistVisibility _visibility;
  late bool _canOwnerSeeTakenWish;

  /// Enregistrement en cours : la page est figée, une modification faite
  /// pendant ce temps serait perdue à la fermeture de la page.
  bool _isSaving = false;

  /// Texte du champ au dernier build : le contrôleur notifie aussi les
  /// déplacements du curseur, qui ne changent rien à la page.
  late String _nameText;

  @override
  void initState() {
    super.initState();
    final wishlist = widget.wishlist;
    _nameText = wishlist.name;
    _nameController = TextEditingController(text: wishlist.name)
      ..addListener(_onNameChanged);
    _color = AppColors.getColorFromHexValue(wishlist.color);
    _visibility = wishlist.visibility;
    _canOwnerSeeTakenWish = wishlist.canOwnerSeeTakenWish;
  }

  @override
  void didUpdateWidget(_WishlistSettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Wishlist modifiée ailleurs : reprendre ses nouvelles valeurs, sauf pour
    // les réglages que l'utilisateur a déjà changés ici
    final previous = oldWidget.wishlist;
    final latest = widget.wishlist;
    if (_nameController.text == previous.name && previous.name != latest.name) {
      // Sans l'écouteur : build suit didUpdateWidget, pas besoin de setState
      _nameController
        ..removeListener(_onNameChanged)
        ..text = latest.name
        ..addListener(_onNameChanged);
      _nameText = latest.name;
    }
    final previousColor = AppColors.getColorFromHexValue(previous.color);
    if (_color == previousColor) {
      _color = AppColors.getColorFromHexValue(latest.color);
    }
    if (_visibility == previous.visibility) {
      _visibility = latest.visibility;
    }
    if (_canOwnerSeeTakenWish == previous.canOwnerSeeTakenWish) {
      _canOwnerSeeTakenWish = latest.canOwnerSeeTakenWish;
    }
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_onNameChanged)
      ..dispose();
    super.dispose();
  }

  void _onNameChanged() {
    // Le titre de l'AppBar, l'erreur et le bouton dépendent du nom
    if (_nameController.text != _nameText) {
      setState(() => _nameText = _nameController.text);
    }
  }

  bool get _isPublic => _visibility == WishlistVisibility.public;

  void _setPublic({required bool isPublic}) {
    setState(() {
      _visibility =
          isPublic ? WishlistVisibility.public : WishlistVisibility.private;
    });
  }

  String get _trimmedName => _nameController.text.trim();

  bool get _isNameValid => _trimmedName.isNotEmpty;

  bool get _hasChanges {
    final wishlist = widget.wishlist;

    // Un nom enregistré avant que les espaces ne soient retirés ne compte
    // pas comme un changement
    return _trimmedName != wishlist.name.trim() ||
        _color != AppColors.getColorFromHexValue(wishlist.color) ||
        _visibility != wishlist.visibility ||
        _canOwnerSeeTakenWish != wishlist.canOwnerSeeTakenWish;
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.wishlistNameRequired;
    }
    return null;
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    // Les autres champs viennent de la dernière version reçue : une
    // modification faite ailleurs entre-temps n'est pas écrasée
    final wishlistUpdated = widget.wishlist.copyWith(
      name: _trimmedName,
      color: AppColors.getHexValue(_color),
      visibility: _visibility,
      canOwnerSeeTakenWish: _canOwnerSeeTakenWish,
    );

    setState(() => _isSaving = true);
    try {
      await ref
          .read(wishlistMutationsProvider.notifier)
          .update(wishlistUpdated);

      if (mounted) {
        showAppSnackBar(
          context,
          l10n.updateSuccess,
          type: SnackBarType.success,
        );
        // Navigator.pop ne consulte pas le PopScope : les changements sont
        // enregistrés, même si le stream n'a pas encore renvoyé la wishlist
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        showGenericError(context, error: e);
      }
    }
  }

  Future<void> _confirmLeave() async {
    final l10n = context.l10n;
    var shouldLeave = false;

    await showAppDialog(
      context,
      title: l10n.unsavedChangesTitle,
      content: Text(
        l10n.unsavedChangesMessage,
        style: AppTextStyles.small.copyWith(color: AppColors.makara),
      ),
      confirmButtonLabel: l10n.unsavedChangesLeave,
      cancelButtonLabel: l10n.unsavedChangesKeepEditing,
      onConfirm: () async {
        shouldLeave = true;
      },
      onCancel: () {},
    );

    if (shouldLeave && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;

    await showAppDialog(
      context,
      title: l10n.deleteWishlist,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.deleteWishlistConfirmation,
            style: AppTextStyles.small.copyWith(color: AppColors.makara),
          ),
          const Gap(8),
          Text(
            l10n.deleteWishlistWishesWarning,
            style: AppTextStyles.smaller.copyWith(color: AppColors.makara),
          ),
        ],
      ),
      confirmButtonLabel: l10n.deleteButton,
      // Une erreur est affichée par le dialog, qui reste ouvert
      onConfirm: () async {
        widget.onDeletingChanged(isDeleting: true);
        try {
          await ref
              .read(wishlistMutationsProvider.notifier)
              .delete(widget.wishlist.id);
        } catch (_) {
          widget.onDeletingChanged(isDeleting: false);
          rethrow;
        }

        if (mounted) {
          HomeRoute().go(context);
          showAppSnackBar(
            context,
            l10n.deleteWishlistSuccess,
            type: SnackBarType.success,
          );
        }
      },
      onCancel: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasChanges = _hasChanges;
    // Garde la mutation (autoDispose) en vie pendant qu'elle s'exécute. Son
    // isLoading couvre aussi la suppression : le bouton suit _isSaving
    ref.watch(wishlistMutationsProvider);
    // Le thème suit la couleur choisie, avant même l'enregistrement
    final theme = getWishlistTheme(
      context,
      widget.wishlist.copyWith(color: AppColors.getHexValue(_color)),
    );

    return PopScope(
      canPop: !hasChanges && !_isSaving,
      onPopInvokedWithResult: (didPop, _) {
        // Pendant l'enregistrement, la page se fermera d'elle-même
        if (!didPop && !_isSaving) {
          _confirmLeave();
        }
      },
      child: Theme(
        data: theme,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: WishlistSettingsAppBar(
            wishlistName: _trimmedName,
            backgroundColor: theme.primaryColor,
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: AbsorbPointer(
                    absorbing: _isSaving,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              controller: _nameController,
                              label: l10n.wishlistNameLabel,
                              icon: Icons.sell_outlined,
                              validator: _validateName,
                              textCapitalization: TextCapitalization.sentences,
                              maxLength: wishlistNameMaxLength,
                            ),
                            if (!_isNameValid)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 6,
                                  left: 16,
                                  right: 16,
                                ),
                                child: Text(
                                  l10n.wishlistNameRequired,
                                  style: AppTextStyles.smaller.copyWith(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const Gap(16),
                            WishlistSettingsCard(
                              icon: Icons.palette_outlined,
                              title: l10n.wishlistColorLabel,
                              // Sous le titre, comme la visibilité : à côté,
                              // les pastilles ne laissent presque rien au
                              // titre sur un écran étroit
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: WishlistColorSelector(
                                  selected: _color,
                                  onSelected: (color) =>
                                      setState(() => _color = color),
                                ),
                              ),
                            ),
                            const Gap(16),
                            MergeSemantics(
                              child: WishlistSettingsCard(
                                icon: _isPublic
                                    ? Icons.public
                                    : Icons.lock_outline,
                                title: l10n.publicWishlistLabel,
                                description: _isPublic
                                    ? l10n.wishlistPublicDescription
                                    : l10n.wishlistPrivateDescription,
                                onTap: () => _setPublic(isPublic: !_isPublic),
                                trailing: AppSwitch(
                                  value: _isPublic,
                                  activeIcon: Icons.public,
                                  inactiveIcon: Icons.lock_outline,
                                  onChanged: (value) =>
                                      _setPublic(isPublic: value),
                                ),
                              ),
                            ),
                            const Gap(16),
                            MergeSemantics(
                              child: WishlistSettingsCard(
                                icon: Icons.card_giftcard,
                                title: l10n.seeBookedWishesLabel,
                                description: _canOwnerSeeTakenWish
                                    ? l10n.seeBookedWishesOnDescription
                                    : l10n.seeBookedWishesOffDescription,
                                onTap: () => setState(
                                  () => _canOwnerSeeTakenWish =
                                      !_canOwnerSeeTakenWish,
                                ),
                                trailing: AppSwitch(
                                  value: _canOwnerSeeTakenWish,
                                  activeIcon: Icons.visibility_rounded,
                                  inactiveIcon: Icons.visibility_off_rounded,
                                  onChanged: (value) => setState(
                                    () => _canOwnerSeeTakenWish = value,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20).copyWith(top: 8),
                  // Comme sur l'écran d'édition d'un wish
                  child: Column(
                    spacing: 12,
                    children: [
                      SecondaryButton(
                        text: l10n.deleteWishlist,
                        onPressed: _isSaving ? null : _confirmDelete,
                        style: BaseButtonStyle.large,
                        isStretched: true,
                      ),
                      PrimaryButton(
                        text: l10n.save,
                        onPressed: hasChanges && _isNameValid ? _save : null,
                        style: BaseButtonStyle.large,
                        isStretched: true,
                        isLoading: _isSaving,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
