import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Retry of the data sources a screen is built from.
///
/// The providers passed to these methods must be the **sources** themselves
/// (the auto-dispose stream providers that hit the network, whose `future` a
/// retry waits for), never a provider derived from them, such as
/// `wishlistThemeProvider` or a screen data provider that combines several
/// streams:
/// - invalidating a derived provider rebuilds it, but it re-reads its sources
///   as they are, so a failed source keeps its error;
/// - a derived provider rebuilds as a fresh `AsyncError` (or a plain
///   `AsyncLoading`) while its sources reload, so it never reports the
///   "loading while still holding an error" state that [isRetryingAny] relies
///   on.
extension RetryProvidersExtension on WidgetRef {
  /// Re-opens only the [providers] that are in error, then waits for them to
  /// settle: the healthy ones keep their data and are not reloaded.
  ///
  /// Completes with the first failure when a retried provider fails again, so
  /// callers that must not let it escape have to catch it.
  Future<void> retryFailed(
    Iterable<AutoDisposeStreamProvider<Object?>> providers,
  ) async {
    final failed = providers.where((provider) => read(provider).hasError);
    // Materialized: re-opening a provider must not change which ones are
    // considered failed
    final toRetry = failed.toList();

    toRetry.forEach(invalidate);
    await Future.wait(
      toRetry.map((provider) => read(provider.future)),
    );
  }

  /// Whether any of the [providers] is reloading after a failure.
  ///
  /// A failed provider reloads as a loading state that still holds its error,
  /// which tells a retry apart from a first load (loading without error).
  /// Watches the providers, so it must be called from a build method.
  bool isRetryingAny(Iterable<AutoDisposeStreamProvider<Object?>> providers) {
    // Every provider is watched (no short-circuit), so that the widget keeps
    // listening to all of them whatever the first results are
    return providers
        .map(
          (provider) => watch(
            provider.select((source) => source.hasError && source.isLoading),
          ),
        )
        .toList()
        .contains(true);
  }
}
