import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/modules/year_recap/share/year_recap_sharer.dart';
import 'package:wishlist/shared/infra/repositories/year_recap/year_recap_repository.dart';
import 'package:wishlist/shared/infra/repositories/year_recap/year_recap_repository_provider.dart';
import 'package:wishlist/shared/models/year_recap/year_recap.dart';

class MockYearRecapRepository extends Mock implements YearRecapRepository {}

/// A recap with the figures that matter to the test, zero for the others.
YearRecapData fakeYearRecap({
  int year = 2026,
  YearRecapStats stats = const YearRecapStats(),
  YearRecapProfileKey profile = YearRecapProfileKey.minimaliste,
  String? illustrationPath,
}) {
  return YearRecapData(
    year: year,
    stats: stats,
    profile: YearRecapProfile(key: profile, illustrationPath: illustrationPath),
  );
}

YearRecapLongestAwaited fakeLongestAwaited({
  String name = 'Casque',
  DateTime? createdOn,
  int days = 185,
}) {
  final created = createdOn ?? DateTime(2025, 6, 2);
  return YearRecapLongestAwaited(
    wishId: 5,
    wishName: name,
    createdOn: created,
    completedOn: created.add(Duration(days: days)),
    days: days,
  );
}

/// Records what the page asks to share, without opening the share sheet.
class FakeYearRecapSharer implements YearRecapSharer {
  final shared = <YearRecapData>[];
  final origins = <Rect?>[];
  Exception? error;

  /// Holds the share until it completes, to look at the page meanwhile.
  Completer<void>? gate;

  @override
  Future<void> share(
    BuildContext context,
    YearRecapData recap, {
    Rect? sharePositionOrigin,
  }) async {
    shared.add(recap);
    origins.add(sharePositionOrigin);
    await gate?.future;
    if (error != null) {
      throw error!;
    }
  }
}

/// A repository that answers [recap] for any year.
Override yearRecapRepositoryOverride(
  YearRecapData recap, {
  void Function(int year)? onLoad,
}) {
  final repository = MockYearRecapRepository();
  when(() => repository.getMyYearRecap(any())).thenAnswer((invocation) async {
    onLoad?.call(invocation.positionalArguments.single as int);
    return recap;
  });
  when(() => repository.illustrationUrl(any()))
      .thenAnswer((i) => 'https://example.com/${i.positionalArguments.single}');
  return yearRecapRepositoryProvider.overrideWithValue(repository);
}

/// An image that always fails to load, without reporting it as a Flutter
/// error: for the places that show something else instead.
class FailingImageProvider extends ImageProvider<FailingImageProvider> {
  @override
  Future<FailingImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    FailingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    final completer = _FailingImageStreamCompleter();
    // Once the image widget is listening
    Future<void>.delayed(
      Duration.zero,
      () => completer.reportError(
        exception: Exception('no network'),
        silent: true,
      ),
    );
    return completer;
  }
}

class _FailingImageStreamCompleter extends ImageStreamCompleter {}
