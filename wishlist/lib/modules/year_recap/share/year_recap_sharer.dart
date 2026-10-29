import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/year_recap/share/year_recap_share_renderer.dart';
import 'package:wishlist/shared/infra/repositories/year_recap/year_recap_repository.dart';
import 'package:wishlist/shared/infra/repositories/year_recap/year_recap_repository_provider.dart';
import 'package:wishlist/shared/models/year_recap/year_recap.dart';

/// Shares the "Ton année Wishy" picture. Behind a provider so that the page
/// can be tested without the system share sheet.
abstract class YearRecapSharer {
  Future<void> share(BuildContext context, YearRecapData recap);
}

class SharePlusYearRecapSharer implements YearRecapSharer {
  SharePlusYearRecapSharer(this._repository);

  final YearRecapRepository _repository;

  @override
  Future<void> share(BuildContext context, YearRecapData recap) async {
    final l10n = context.l10n;
    final path = recap.profile.illustrationPath;
    final png = await renderYearRecapShareImage(
      context: context,
      recap: recap,
      l10n: l10n,
      illustrationUrl: path == null ? null : _repository.illustrationUrl(path),
    );
    await SharePlus.instance.share(
      ShareParams(
        text: l10n.yearRecapShareText('${recap.year}'),
        files: [
          XFile.fromData(
            png,
            mimeType: 'image/png',
            name: 'wishy-${recap.year}.png',
          ),
        ],
      ),
    );
  }
}

final yearRecapSharerProvider = Provider.autoDispose<YearRecapSharer>((ref) {
  return SharePlusYearRecapSharer(ref.watch(yearRecapRepositoryProvider));
});
