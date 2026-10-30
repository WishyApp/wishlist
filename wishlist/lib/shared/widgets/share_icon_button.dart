import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wishlist/shared/utils/share_utils.dart';

/// Share button anchoring the share sheet on itself (required on iPad)
class ShareIconButton extends StatelessWidget {
  const ShareIconButton({
    super.key,
    required this.params,
    this.onError,
    this.iconSize = 32,
  });

  /// Built on tap, so the content is always up to date
  final ShareParams Function() params;
  final ValueChanged<Object>? onError;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    // The button's own context is what gives its area
    return Builder(
      builder: (buttonContext) => IconButton(
        icon: Icon(Icons.share, size: iconSize),
        onPressed: () async {
          try {
            await shareFrom(buttonContext, params());
          } catch (e) {
            // The page may have closed while the share sheet was open
            if (buttonContext.mounted) {
              onError?.call(e);
            }
          }
        },
      ),
    );
  }
}
