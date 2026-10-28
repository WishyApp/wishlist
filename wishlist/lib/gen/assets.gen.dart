/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: directives_ordering,unnecessary_import,implicit_dynamic_list_literal,deprecated_member_use

import 'package:flutter/widgets.dart';

class $EnvGen {
  const $EnvGen();

  /// File path: env/.env.dev
  String get aEnvDev => 'env/.env.dev';

  /// File path: env/.env.prod
  String get aEnvProd => 'env/.env.prod';

  /// List of all assets
  List<String> get values => [aEnvDev, aEnvProd];
}

class $AssetsLogoGen {
  const $AssetsLogoGen();

  /// File path: assets/logo/wishy_logo.png
  AssetGenImage get wishyLogo =>
      const AssetGenImage('assets/logo/wishy_logo.png');

  /// List of all assets
  List<AssetGenImage> get values => [wishyLogo];
}

class $AssetsSvgGen {
  const $AssetsSvgGen();

  /// File path: assets/svg/birthday.svg
  String get birthday => 'assets/svg/birthday.svg';

  /// File path: assets/svg/google_logo.svg
  String get googleLogo => 'assets/svg/google_logo.svg';

  /// File path: assets/svg/no_booked_wish.svg
  String get noBookedWish => 'assets/svg/no_booked_wish.svg';

  /// File path: assets/svg/no_connection.svg
  String get noConnection => 'assets/svg/no_connection.svg';

  /// File path: assets/svg/no_friend.svg
  String get noFriend => 'assets/svg/no_friend.svg';

  /// File path: assets/svg/no_wish_bag.svg
  String get noWishBag => 'assets/svg/no_wish_bag.svg';

  /// File path: assets/svg/no_wish_box_hat.svg
  String get noWishBoxHat => 'assets/svg/no_wish_box_hat.svg';

  /// File path: assets/svg/no_wish_flashlight.svg
  String get noWishFlashlight => 'assets/svg/no_wish_flashlight.svg';

  /// File path: assets/svg/no_wishlist.svg
  String get noWishlist => 'assets/svg/no_wishlist.svg';

  /// File path: assets/svg/pseudo.svg
  String get pseudo => 'assets/svg/pseudo.svg';

  /// File path: assets/svg/server_error.svg
  String get serverError => 'assets/svg/server_error.svg';

  /// List of all assets
  List<String> get values => [
        birthday,
        googleLogo,
        noBookedWish,
        noConnection,
        noFriend,
        noWishBag,
        noWishBoxHat,
        noWishFlashlight,
        noWishlist,
        pseudo,
        serverError,
      ];
}

class Assets {
  const Assets._();

  static const $AssetsLogoGen logo = $AssetsLogoGen();
  static const $AssetsSvgGen svg = $AssetsSvgGen();
  static const $EnvGen env = $EnvGen();
}

class AssetGenImage {
  const AssetGenImage(this._assetName, {this.size, this.flavors = const {}});

  final String _assetName;

  final Size? size;
  final Set<String> flavors;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.medium,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({AssetBundle? bundle, String? package}) {
    return AssetImage(_assetName, bundle: bundle, package: package);
  }

  String get path => _assetName;

  String get keyName => _assetName;
}
