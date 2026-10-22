import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/shared/utils/retry_providers_extension.dart';

void main() {
  late int healthyBuilds;
  late int failingBuilds;
  late Completer<int> reload;
  late bool failsAgain;
  late WidgetRef capturedRef;
  late bool isRetrying;

  final healthyProvider = StreamProvider.autoDispose<int>((ref) {
    healthyBuilds++;
    return Stream.value(1);
  });
  final failingProvider = StreamProvider.autoDispose<int>((ref) {
    failingBuilds++;
    if (failingBuilds == 1 || failsAgain) {
      return Stream.error(Exception('offline'));
    }
    return Stream.fromFuture(reload.future);
  });

  setUp(() {
    healthyBuilds = 0;
    failingBuilds = 0;
    failsAgain = false;
    isRetrying = false;
  });

  Future<void> pumpHost(WidgetTester tester) async {
    // Created in the test body, so that its callbacks run on the fake clock
    reload = Completer<int>();
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            capturedRef = ref;
            isRetrying = ref.isRetryingAny([healthyProvider, failingProvider]);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Futures only progress while the tester pumps the fake clock.
  Future<Object?> completion(WidgetTester tester, Future<void> future) async {
    var isDone = false;
    Object? error;
    unawaited(
      future.then<void>((_) {}, onError: (Object e) => error = e).whenComplete(
            () => isDone = true,
          ),
    );
    for (var i = 0; i < 10 && !isDone; i++) {
      await tester.pump();
    }
    expect(isDone, isTrue, reason: 'the retry never completed');
    return error;
  }

  testWidgets('retryFailed only re-opens the providers in error',
      (tester) async {
    await pumpHost(tester);
    expect(healthyBuilds, 1);
    expect(failingBuilds, 1);

    final retry = capturedRef.retryFailed([healthyProvider, failingProvider]);
    reload.complete(2);
    expect(await completion(tester, retry), isNull);

    expect(healthyBuilds, 1);
    expect(failingBuilds, 2);
    expect(capturedRef.read(failingProvider).valueOrNull, 2);
  });

  testWidgets('retryFailed does nothing when no provider failed',
      (tester) async {
    await pumpHost(tester);

    final retry = capturedRef.retryFailed([healthyProvider]);
    expect(await completion(tester, retry), isNull);

    expect(healthyBuilds, 1);
    expect(failingBuilds, 1);
  });

  testWidgets('retryFailed completes with the error of a new failure',
      (tester) async {
    await pumpHost(tester);
    failsAgain = true;

    final retry = capturedRef.retryFailed([failingProvider]);

    expect(await completion(tester, retry), isException);
    expect(failingBuilds, 2);
  });

  testWidgets('isRetryingAny is only true while a failed provider reloads',
      (tester) async {
    await pumpHost(tester);
    // A failure alone is not a retry, nor is a healthy provider
    expect(isRetrying, isFalse);

    final retry = capturedRef.retryFailed([failingProvider]);
    await tester.pump();
    expect(isRetrying, isTrue);

    reload.complete(2);
    expect(await completion(tester, retry), isNull);
    await tester.pump();
    expect(isRetrying, isFalse);
  });

  testWidgets('isRetryingAny is false during a first load', (tester) async {
    final pending = Completer<int>();
    final loadingProvider = StreamProvider.autoDispose<int>(
      (ref) => Stream.fromFuture(pending.future),
    );
    late bool result;

    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            result = ref.isRetryingAny([loadingProvider]);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(result, isFalse);
    pending.complete(1);
    await tester.pump();
  });

  testWidgets('isRetryingAny watches every provider, not only up to the first',
      (tester) async {
    // Once the first provider is retrying, a short-circuit would stop
    // watching the second one, so a retry of it would not rebuild the widget
    var firstBuilds = 0;
    var secondBuilds = 0;
    late Completer<int> firstReload;
    late Completer<int> secondReload;
    final firstProvider = StreamProvider.autoDispose<int>((ref) {
      return ++firstBuilds == 1
          ? Stream.error(Exception('offline'))
          : Stream.fromFuture(firstReload.future);
    });
    final secondProvider = StreamProvider.autoDispose<int>((ref) {
      return ++secondBuilds == 1
          ? Stream.error(Exception('offline'))
          : Stream.fromFuture(secondReload.future);
    });
    var hostBuilds = 0;
    late WidgetRef ref;
    late bool result;
    firstReload = Completer<int>();
    secondReload = Completer<int>();

    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, widgetRef, _) {
            hostBuilds++;
            ref = widgetRef;
            result = widgetRef.isRetryingAny([firstProvider, secondProvider]);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final firstRetry = ref.retryFailed([firstProvider]);
    await tester.pump();
    expect(result, isTrue);

    final buildsBeforeSecondRetry = hostBuilds;
    final secondRetry = ref.retryFailed([secondProvider]);
    await tester.pump();
    expect(hostBuilds, greaterThan(buildsBeforeSecondRetry));

    // The second one is still retrying once the first one is done
    firstReload.complete(1);
    expect(await completion(tester, firstRetry), isNull);
    await tester.pump();
    expect(result, isTrue);

    secondReload.complete(2);
    expect(await completion(tester, secondRetry), isNull);
    await tester.pump();
    expect(result, isFalse);
  });
}
