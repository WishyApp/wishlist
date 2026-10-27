import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_color_selector.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_settings_app_bar.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_settings_card.dart';
import 'package:wishlist/modules/wishlists/view/widgets/wishlist_visibility_selector.dart';
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

  @override
  Widget build(BuildContext context) {
    final provider = watchWishlistByIdProvider(widget.wishlistId);
    final wishlistAsync = ref.watch(provider);
    final isMutating = ref.watch(wishlistMutationsProvider).isLoading;

    return wishlistAsync.when(
      // A failed refetch must not unmount the form and lose the user's edits
      skipError: wishlistAsync.hasValue,
      data: (wishlist) {
        if (wishlist != null) {
          _lastWishlist = wishlist;
        }
        final shownWishlist = wishlist ?? (isMutating ? _lastWishlist : null);
        if (shownWishlist == null) {
          return ErrorPageWithBack.unavailable(
            message: context.l10n.wishlistDeleted,
          );
        }

        return _WishlistSettingsForm(wishlist: shownWishlist);
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
  const _WishlistSettingsForm({required this.wishlist});

  /// Dernière version enregistrée de la wishlist, mise à jour en temps réel.
  final Wishlist wishlist;

  @override
  ConsumerState<_WishlistSettingsForm> createState() =>
      _WishlistSettingsFormState();
}

class _WishlistSettingsFormState extends ConsumerState<_WishlistSettingsForm> {
  late final TextEditingController _nameController;
  late Color _color;
  late WishlistVisibility _visibility;
  late bool _canOwnerSeeTakenWish;

  @override
  void initState() {
    super.initState();
    final wishlist = widget.wishlist;
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
    setState(() {});
  }

  String get _trimmedName => _nameController.text.trim();

  bool get _isNameValid => _trimmedName.isNotEmpty;

  bool get _hasChanges {
    final wishlist = widget.wishlist;

    return _trimmedName != wishlist.name ||
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
        await ref
            .read(wishlistMutationsProvider.notifier)
            .delete(widget.wishlist.id);

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
    final isLoading = ref.watch(wishlistMutationsProvider).isLoading;
    // Le thème suit la couleur choisie, avant même l'enregistrement
    final theme = getWishlistTheme(
      context,
      widget.wishlist.copyWith(color: AppColors.getHexValue(_color)),
    );

    return PopScope(
      canPop: !hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
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
                            trailing: WishlistColorSelector(
                              selected: _color,
                              onSelected: (color) =>
                                  setState(() => _color = color),
                            ),
                          ),
                          const Gap(16),
                          WishlistSettingsCard(
                            icon: Icons.public,
                            title: l10n.wishlistVisibilityLabel,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                WishlistVisibilitySelector(
                                  selected: _visibility,
                                  onSelected: (visibility) => setState(
                                    () => _visibility = visibility,
                                  ),
                                ),
                                const Gap(8),
                                Text(
                                  _visibility == WishlistVisibility.public
                                      ? l10n.wishlistPublicDescription
                                      : l10n.wishlistPrivateDescription,
                                  style: AppTextStyles.smaller.copyWith(
                                    color: AppColors.makara,
                                  ),
                                ),
                              ],
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
                              trailing: Switch(
                                value: _canOwnerSeeTakenWish,
                                activeTrackColor: theme.primaryColor,
                                inactiveTrackColor: AppColors.pastelGray,
                                inactiveThumbColor: AppColors.background,
                                trackOutlineColor: const WidgetStatePropertyAll(
                                  Colors.transparent,
                                ),
                                onChanged: (value) => setState(
                                  () => _canOwnerSeeTakenWish = value,
                                ),
                              ),
                            ),
                          ),
                          const Gap(16),
                          TextButton.icon(
                            onPressed: _confirmDelete,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              minimumSize: const Size.fromHeight(48),
                              textStyle: AppTextStyles.small.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            icon: const Icon(Icons.delete_outline),
                            label: Text(l10n.deleteWishlist),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20).copyWith(top: 8),
                  child: PrimaryButton(
                    text: l10n.save,
                    onPressed: hasChanges && _isNameValid ? _save : null,
                    style: BaseButtonStyle.large,
                    isStretched: true,
                    isLoading: isLoading,
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
