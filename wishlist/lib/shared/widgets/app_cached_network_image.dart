import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:wishlist/shared/theme/colors.dart';

/// Image widget to show NetworkImage with caching and mock functionalities.
abstract class AppCachedNetworkImage extends StatelessWidget {
  /// Constructor for [AppCachedNetworkImage].
  const AppCachedNetworkImage({super.key});

  /// The loaded constructor for [AppCachedNetworkImage].
  factory AppCachedNetworkImage.loaded({
    required String src,
    double? height,
    double? width,
    BoxFit? fit,
    Color? placeholderColor,
  }) = _LoadedAppCachedNetworkImage;

  /// The loading constructor for [AppCachedNetworkImage].
  const factory AppCachedNetworkImage.loading({
    double? height,
    double? width,
    Color? placeholderColor,
  }) = _LoadingAppCachedNetworkImage;

  /// The error constructor for [AppCachedNetworkImage].
  const factory AppCachedNetworkImage.error({
    double? height,
    double? width,
    Color? placeholderColor,
  }) = _ErrorAppCachedNetworkImage;
}

/// Image widget to show NetworkImage with caching and mock functionalities.
class _LoadedAppCachedNetworkImage extends AppCachedNetworkImage {
  /// ImageWithFallback shows a network image using a caching mechanism. It also
  /// handles images errors by displaying an [_ErrorAppCachedNetworkImage].
  ///
  /// To avoid cache errors during tests, wrap your test widget in a
  /// [InheritedCacheManager] and override the cache manager with a mock.
  ///
  /// To render an image during tests, wrap your test widget in a
  /// [InheritedCachedImageOverride], and set the property
  /// `defaultImage` to your wanted assetImage.
  _LoadedAppCachedNetworkImage({
    required this.src,
    this.height,
    this.width,
    this.fit,
    this.placeholderColor,
  }) :
        // Assert will not handle edge case in release mode. Unsupported images
        // are handled by [CachedNetworkImage] and the `errorWidget` builder.
        // The assert is here to help debug.
        assert(src.startsWith('https://'), 'Only image url are supported');

  /// Image source. For now, only url are supported.
  final String src;

  ///   If non-null, require the image to have this height.
  ///
  /// If null, the image will pick a size that best preserves its intrinsic
  /// aspect ratio. This may result in a sudden change if the size of the
  /// placeholder widget does not match that of the target image. The size is
  /// also affected by the scale factor.
  final double? height;

  /// If non-null, require the image to have this width.
  ///
  /// If null, the image will pick a size that best preserves its intrinsic
  /// aspect ratio. This may result in a sudden change if the size of the
  /// placeholder widget does not match that of the target image. The size is
  /// also affected by the scale factor.
  final double? width;

  /// How to inscribe the image into the space allocated during layout.
  ///
  /// The default varies based on the other fields. See the discussion at
  /// [paintImage].
  final BoxFit? fit;

  /// Color used for loading and error placeholders.
  ///
  /// Defaults to [AppColors.background].
  final Color? placeholderColor;

  @override
  Widget build(BuildContext context) {
    final defaultImage = InheritedCachedImageOverride.of(context);
    if (defaultImage != null) {
      final sizedDefaultImage = SizedBox(
        height: height,
        width: width,
        child: defaultImage,
      );

      final fit = this.fit;

      return fit == null
          ? sizedDefaultImage
          : FittedBox(fit: fit, child: sizedDefaultImage);
    }

    // Si le délai est activé, on attend avant de charger l'image
    // Utile pour tester le comportement lors de chargements lents
    if (_enableImageLoadingDelay) {
      return FutureBuilder<void>(
        future: Future.delayed(_imageLoadingDelay),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return _buildNetworkImage(context);
          }
          return _LoadingAppCachedNetworkImage(
            height: height,
            width: width,
            placeholderColor: placeholderColor,
          );
        },
      );
    }

    return _buildNetworkImage(context);
  }

  Widget _buildNetworkImage(BuildContext context) {
    final cacheManager = InheritedCacheManager.of(context);

    // Si height et width sont spécifiés, on utilise imageBuilder
    // pour mieux contrôler l'affichage et éviter la déformation
    if (height != null && width != null) {
      return SizedBox(
        width: width,
        height: height,
        child: CachedNetworkImage(
          imageUrl: src,
          cacheManager: cacheManager,
          fadeInDuration: kThemeAnimationDuration,
          fadeOutDuration: kThemeAnimationDuration,
          progressIndicatorBuilder: (_, __, ___) =>
              _LoadingAppCachedNetworkImage(
            height: height,
            width: width,
            placeholderColor: placeholderColor,
          ),
          errorWidget: (_, __, dynamic ___) => _ErrorAppCachedNetworkImage(
            height: height,
            width: width,
            placeholderColor: placeholderColor,
          ),
          // Pas de memCacheWidth/Height ici : l'imageBuilder reçoit le provider
          // brut, ils provoqueraient un second décodage sans redimensionner
          // l'image affichée. Les passer aussi à un ResizeImage dans
          // l'imageBuilder déformerait l'image (les deux dimensions sont
          // imposées au décodage) et fixer une seule dimension ne suffit pas
          // pour `cover`, dont l'échelle dépend du ratio de l'image.
          imageBuilder: (context, imageProvider) => Image(
            image: imageProvider,
            width: width,
            height: height,
            fit: fit ?? BoxFit.cover,
          ),
        ),
      );
    }

    // Si seulement height ou width est spécifié, on utilise SizedBox
    if (height != null || width != null) {
      final memCacheSize = computeMemCacheSize(
        width: width,
        height: height,
        fit: fit,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      );

      return SizedBox(
        height: height,
        width: width,
        child: CachedNetworkImage(
          imageUrl: src,
          cacheManager: cacheManager,
          fadeInDuration: kThemeAnimationDuration,
          fadeOutDuration: kThemeAnimationDuration,
          fit: fit,
          memCacheWidth: memCacheSize.width,
          memCacheHeight: memCacheSize.height,
          progressIndicatorBuilder: (_, __, ___) =>
              _LoadingAppCachedNetworkImage(
            height: height,
            width: width,
            placeholderColor: placeholderColor,
          ),
          errorWidget: (_, __, dynamic ___) => _ErrorAppCachedNetworkImage(
            height: height,
            width: width,
            placeholderColor: placeholderColor,
          ),
        ),
      );
    }

    // Aucune contrainte de taille : pas de memCache, l'image garde sa taille
    return CachedNetworkImage(
      imageUrl: src,
      cacheManager: cacheManager,
      fadeInDuration: kThemeAnimationDuration,
      fadeOutDuration: kThemeAnimationDuration,
      fit: fit,
      progressIndicatorBuilder: (_, __, ___) => _LoadingAppCachedNetworkImage(
        height: height,
        width: width,
        placeholderColor: placeholderColor,
      ),
      errorWidget: (_, __, dynamic ___) => _ErrorAppCachedNetworkImage(
        height: height,
        width: width,
        placeholderColor: placeholderColor,
      ),
    );
  }
}

/// Widget used to show the loading progress of an image
class _LoadingAppCachedNetworkImage extends AppCachedNetworkImage {
  /// default constructor.
  const _LoadingAppCachedNetworkImage({
    this.height,
    this.width,
    this.placeholderColor,
  });

  /// height of the [_LoadingAppCachedNetworkImage]
  final double? height;

  /// width of the [_LoadingAppCachedNetworkImage]
  final double? width;

  /// Color used for the loading placeholder background.
  ///
  /// Defaults to [AppColors.background].
  final Color? placeholderColor;

  @override
  Widget build(BuildContext context) {
    return _AppCachedNetworkImageLayout(
      height: height,
      width: width,
      child: Container(
        color: placeholderColor ?? AppColors.background,
        padding: const EdgeInsets.all(8),
        child: const CircularProgressIndicator(
          color: AppColors.makara,
        ),
      ),
    );
  }
}

/// Widget used to show a placeholder instead of an image
///
/// It can be used on error cases or if no image is provided
class _ErrorAppCachedNetworkImage extends AppCachedNetworkImage {
  /// default constructor.
  const _ErrorAppCachedNetworkImage({
    this.height,
    this.width,
    this.placeholderColor,
  });

  /// height of the [_ErrorAppCachedNetworkImage]
  final double? height;

  /// width of the [_ErrorAppCachedNetworkImage]
  final double? width;

  /// Color used for the error placeholder background.
  ///
  /// Defaults to [AppColors.background].
  final Color? placeholderColor;

  @override
  Widget build(BuildContext context) {
    return _AppCachedNetworkImageLayout(
      height: height,
      width: width,
      child: ColoredBox(
        color: placeholderColor ?? AppColors.background,
        child: const Icon(
          Icons.image_not_supported,
          color: AppColors.makara,
        ),
      ),
    );
  }
}

class _AppCachedNetworkImageLayout extends StatelessWidget {
  const _AppCachedNetworkImageLayout({
    this.height,
    this.width,
    required this.child,
  });

  final double? height;
  final double? width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Convertit en pixels physiques l'unique dimension connue ([width] ou
/// [height], en pixels logiques) d'une image réseau.
///
/// Une seule dimension est renvoyée pour que le décodeur conserve le ratio de
/// l'image (fixer les deux l'étire). Les dimensions absentes, non finies ou
/// inférieures ou égales à zéro sont ignorées.
///
/// Rien n'est renvoyé si la taille décodée risque d'être inférieure à celle
/// affichée : width et height tous deux renseignés (le cas de l'`imageBuilder`,
/// voir plus haut), ou un [fit] dont l'échelle dépend de l'autre axe, qui suit
/// les contraintes du parent et non le ratio de l'image (`cover`, `fill`,
/// `none`, et `fitHeight` / `fitWidth` pour la dimension qu'ils ne fixent pas).
/// Un [fit] null vaut `scaleDown`, comme dans [paintImage].
@visibleForTesting
({int? width, int? height}) computeMemCacheSize({
  required double? width,
  required double? height,
  required BoxFit? fit,
  required double devicePixelRatio,
}) {
  double? valid(double? value) =>
      value != null && value.isFinite && value > 0 ? value : null;

  final w = valid(width);
  final h = valid(height);
  if (w != null && h == null && _fitKeepsWidthScale(fit)) {
    return (width: (w * devicePixelRatio).ceil(), height: null);
  }
  if (h != null && w == null && _fitKeepsHeightScale(fit)) {
    return (width: null, height: (h * devicePixelRatio).ceil());
  }
  return (width: null, height: null);
}

// L'échelle d'affichage ne dépasse jamais celle donnée par la largeur.
bool _fitKeepsWidthScale(BoxFit? fit) =>
    fit == null ||
    fit == BoxFit.contain ||
    fit == BoxFit.scaleDown ||
    fit == BoxFit.fitWidth;

// L'échelle d'affichage ne dépasse jamais celle donnée par la hauteur.
bool _fitKeepsHeightScale(BoxFit? fit) =>
    fit == null ||
    fit == BoxFit.contain ||
    fit == BoxFit.scaleDown ||
    fit == BoxFit.fitHeight;

/// Constante pour activer/désactiver le délai artificiel de chargement
///
/// Mettre à `true` pour simuler un chargement lent lors des tests.
/// Mettre à `false` en production.
const bool _enableImageLoadingDelay = false;

/// Durée du délai artificiel (en secondes)
///
/// Utilisé uniquement si `_enableImageLoadingDelay` est à `true`.
const Duration _imageLoadingDelay = Duration(seconds: 2);

/// Establish a subtree in which cache manager resolves to the given data.
/// Use `InheritedCacheManager.of(context)` to retrieve the data in any child
/// widget.
///
/// Typical usage is:
/// ```dart
/// InheritedCacheManager(
///  cacheManagerOverride: MockCacheManager(),
///  child: MyWidget(),
/// );
///```
///
/// See also: [CacheManager].
@visibleForTesting
class InheritedCacheManager extends InheritedWidget {
  /// Creates a widget that provides a [CacheManager] to its descendants.
  ///
  /// The [child] argument must not be null.
  const InheritedCacheManager({
    super.key,
    this.cacheManagerOverride,
    required super.child,
  });

  /// Override the default cache manager for the subtree.
  ///
  /// Default is [DefaultCacheManager].
  final CacheManager? cacheManagerOverride;

  /// The data from the closest instance of this class that encloses the given
  /// context.
  ///
  /// You can use this method to retrieve the [CacheManager].
  ///
  /// Typical usage is as follows:
  ///
  /// ```dart
  /// final cacheManager = InheritedCacheManager.of(context);
  /// ```
  static CacheManager of(BuildContext context) {
    final result =
        context.dependOnInheritedWidgetOfExactType<InheritedCacheManager>();

    return result?.cacheManagerOverride ?? DefaultCacheManager();
  }

  @override
  bool updateShouldNotify(covariant InheritedCacheManager oldWidget) =>
      oldWidget.cacheManagerOverride != cacheManagerOverride;
}

/// Establish a subtree in which [defaultImage] resolves to the given data.
/// Use `InheritedCachedImageOverride.of(context) to retrieve the data in any
/// child widget.
///
/// Typical usage is:
/// ```dart
/// InheritedCachedImageOverride(
///  defaultImage: AssetImage(
///     'assets/default_photo.jpg',
///     package: 'enterprise_go_theme',
///     ),
///  child: MyWidget(),
/// );
///```
///
/// See also: [AppCachedNetworkImage].
@visibleForTesting
class InheritedCachedImageOverride extends InheritedWidget {
  /// Creates a widget that provides [defaultImage]
  /// to its descendants.
  ///
  /// The [child] argument must not be null.
  const InheritedCachedImageOverride({
    super.key,
    this.defaultImage,
    required super.child,
  });

  /// Tells to widgets in the subtree, the default widget to use to override
  /// others images.
  final Widget? defaultImage;

  /// The data from the closest instance of this class that encloses the given
  /// context.
  ///
  /// You can use this method to know if an Image should be overridden.
  ///
  /// Typical usage is as follows:
  ///
  /// ```dart
  /// final defaultImage = InheritedCachedImageOverride.of(context);
  /// ```
  static Widget? of(BuildContext context) {
    final result = context
        .dependOnInheritedWidgetOfExactType<InheritedCachedImageOverride>();

    return result?.defaultImage;
  }

  @override
  bool updateShouldNotify(covariant InheritedCachedImageOverride oldWidget) =>
      oldWidget.defaultImage != defaultImage;
}
