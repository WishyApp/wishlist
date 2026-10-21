import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/infra/share_intent_payload_provider.dart';
import 'package:wishlist/shared/infra/wishlists_realtime_provider.dart';
import 'package:wishlist/shared/models/wish_prefill_data/wish_prefill_data.dart';
import 'package:wishlist/shared/models/wishlist/wishlist.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/page_layout_error/page_layout_error.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/utils/retry_providers_extension.dart';
import 'package:wishlist/shared/widgets/wishlist_list_tile.dart';

/// Écran affiché quand on arrive via partage (add-wish) sans wishlist connue.
/// Redirige vers le formulaire de création dans la bonne wishlist
/// (choix si plusieurs).
class AddWishScreen extends ConsumerStatefulWidget {
  const AddWishScreen({
    super.key,
    this.prefill,
  });

  final WishPrefillData? prefill;

  @override
  ConsumerState<AddWishScreen> createState() => _AddWishScreenState();
}

class _AddWishScreenState extends ConsumerState<AddWishScreen> {
  /// Prefill venant du partage (provider) ou de la route (URL).
  /// Rempli dans addPostFrameCallback : consume() modifie le provider,
  /// interdit pendant initState/build (Riverpod).
  WishPrefillData? _prefill;

  /// Image reçue via partage, transmise au formulaire par la route.
  String? _sharedImagePath;

  /// Évite les navigations en double : un seul des deux déclencheurs
  /// (post-frame ou listen) exécute la navigation.
  bool _navigationHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _consumeSharePayload(isFirstRead: true);
    });
  }

  /// Lit (et vide) le partage en attente, puis relance la navigation.
  ///
  /// Appelé au montage, puis à chaque nouveau partage reçu pendant que
  /// l'écran est affiché : `router.go('/add-wish')` vers la même adresse
  /// garde la même page, donc `initState` ne repasse pas.
  void _consumeSharePayload({bool isFirstRead = false}) {
    final payload =
        ref.read(shareIntentPayloadNotifierProvider.notifier).consume();
    final isEmpty = payload.prefill == null && payload.imagePath == null;
    if (isEmpty && !isFirstRead) {
      // Déjà consommé (montage et écoute simultanés) : garder l'actuel.
      return;
    }
    _prefill = payload.prefill ?? (isFirstRead ? widget.prefill : null);
    _sharedImagePath = payload.imagePath;
    _navigationHandled = false;
    _resolveNavigation();
  }

  /// Navigue directement vers le formulaire s'il n'y a qu'une wishlist.
  /// Sans wishlist, le build affiche un message ; avec plusieurs, un choix.
  void _tryNavigateFromWishlists(List<Wishlist> wishlists) {
    if (!mounted || _navigationHandled) {
      return;
    }
    if (wishlists.length == 1) {
      _navigationHandled = true;
      _goToCreateWish(wishlists.first.id);
    }
  }

  /// Données déjà dispo au premier frame (ex. cache) : on navigue sans
  /// attendre le listen.
  void _resolveNavigation() {
    if (!mounted) {
      return;
    }
    ref.read(wishlistsRealtimeProvider).whenData(_tryNavigateFromWishlists);
  }

  void _goToCreateWish(int wishlistId) {
    CreateWishRoute(
      wishlistId: wishlistId,
      name: _prefill?.name,
      link: _prefill?.linkUrl,
      description: _prefill?.description,
      price: _prefill?.price?.toString(),
      $extra: _sharedImagePath,
    ).go(context);
  }

  /// AppBar with a back button, shared by every state of the screen so the
  /// user can always leave it, including while the wishlists are loading.
  AppBar _buildBackAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Nouveau partage alors que l'écran est déjà affiché : le consommer.
    // En microtâche, car on ne modifie pas un provider pendant qu'il notifie.
    ref.listen(shareIntentPayloadNotifierProvider, (prev, next) {
      if (next.prefill == null && next.imagePath == null) {
        return;
      }
      Future.microtask(() {
        if (mounted) {
          _consumeSharePayload();
        }
      });
    });
    // Quand le provider passe en data après un loading, naviguer s'il n'y a
    // qu'une wishlist (WidgetRef.listen n'a pas fireImmediately).
    ref.listen(wishlistsRealtimeProvider, (prev, next) {
      next.whenData(_tryNavigateFromWishlists);
    });
    final wishlistsAsync = ref.watch(wishlistsRealtimeProvider);

    return wishlistsAsync.when(
      data: (wishlists) {
        if (wishlists.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: _buildBackAppBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.noWishlist,
                  style: AppTextStyles.medium.copyWith(color: AppColors.makara),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        if (wishlists.length == 1) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: _buildBackAppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return _WishlistSelectionContent(
          wishlists: wishlists,
          onSelectWishlist: _goToCreateWish,
        );
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildBackAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildBackAppBar(),
        body: PageLayoutError(
          error: error,
          onRetry: () => ref.retryFailed([wishlistsRealtimeProvider]),
          isRetrying: ref.isRetryingAny([wishlistsRealtimeProvider]),
        ),
      ),
    );
  }
}

class _WishlistSelectionContent extends StatelessWidget {
  const _WishlistSelectionContent({
    required this.wishlists,
    required this.onSelectWishlist,
  });

  final List<Wishlist> wishlists;
  final void Function(int wishlistId) onSelectWishlist;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sorted = List<Wishlist>.from(wishlists)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l10n.selectWishlist,
          style: AppTextStyles.medium.copyWith(color: AppColors.darkGrey),
        ),
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: sorted.length,
        itemBuilder: (context, index) {
          final wishlist = sorted[index];
          return WishlistListTile(
            wishlist: wishlist,
            onTap: () => onSelectWishlist(wishlist.id),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          );
        },
      ),
    );
  }
}
