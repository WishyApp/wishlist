import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wishlist/shared/infra/avatar_service.dart';
import 'package:wishlist/shared/infra/current_user_avatar_provider.dart';
import 'package:wishlist/shared/infra/repositories/user/user_streams_providers.dart';
import 'package:wishlist/shared/models/profile.dart';
import 'package:wishlist/shared/widgets/avatar/app_avatar.dart';
import 'package:wishlist/shared/widgets/avatar/editable_avatar.dart';

import '../../../pump_app.dart';

class MockAvatarService extends Mock implements AvatarService {}

Profile _profile(String? avatarUrl) =>
    Profile(id: 'user-1', pseudo: 'pseudo', avatarUrl: avatarUrl);

/// Replays the latest profile to each new listener, like the real stream
/// provider does when Settings is opened again.
class _ProfileFeed {
  final _controller = StreamController<Profile?>.broadcast();

  /// Assigning it emits nothing, like a realtime event missed while the
  /// channel was rejoining: only a new select sees the change.
  Profile? stored;

  Stream<Profile?> get stream => Stream.multi((listener) {
        if (stored != null) {
          listener.add(stored);
        }
        final subscription = _controller.stream.listen(listener.add);
        listener.onCancel = subscription.cancel;
      });

  void emit(Profile? profile) {
    stored = profile;
    _controller.add(profile);
  }
}

void main() {
  late MockAvatarService avatarService;
  late _ProfileFeed feed;

  setUpAll(() {
    registerFallbackValue(File('avatar.png'));
  });

  setUp(() {
    avatarService = MockAvatarService();
    // An empty url makes AppAvatar render its placeholder, no network image.
    when(() => avatarService.getAvatarUrl(any())).thenReturn('');
    feed = _ProfileFeed();
  });

  Future<void> pumpAvatar(WidgetTester tester, {bool visible = true}) {
    return tester.pumpApp(
      visible ? const EditableAvatar() : const SizedBox.shrink(),
      overrides: [
        avatarServiceProvider.overrideWithValue(avatarService),
        watchCurrentUserProfileProvider.overrideWith((ref) => feed.stream),
      ],
    );
  }

  String? displayedAvatarUrl(WidgetTester tester) =>
      tester.widget<AppAvatar>(find.byType(AppAvatar)).avatarUrl;

  testWidgets('shows the avatar of the profile stream and follows it',
      (tester) async {
    feed.emit(_profile('path-1'));
    await pumpAvatar(tester);
    await tester.pump();

    expect(displayedAvatarUrl(tester), 'path-1');

    feed.emit(_profile('path-2'));
    await tester.pump();

    expect(displayedAvatarUrl(tester), 'path-2');
  });

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(EditableAvatar)));

  testWidgets(
      'keeps the spinner during an upload then shows the new avatar, '
      'without showing the old one again', (tester) async {
    final upload = Completer<String>();
    when(() => avatarService.uploadAvatar(any()))
        .thenAnswer((_) => upload.future);
    feed.emit(_profile('path-1'));
    await pumpAvatar(tester);
    await tester.pump();

    unawaited(
      containerOf(tester)
          .read(avatarEditProvider.notifier)
          .uploadAvatar(File('a.png')),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(AppAvatar), findsNothing);

    feed.stored = _profile('path-2');
    upload.complete('path-2');
    // Every frame until the end: the old avatar must never come back.
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      if (find.byType(AppAvatar).evaluate().isNotEmpty) {
        expect(displayedAvatarUrl(tester), 'path-2');
      }
    }

    expect(displayedAvatarUrl(tester), 'path-2');
  });

  testWidgets(
      'shows the new avatar after an upload even if the stream emitted '
      'nothing', (tester) async {
    when(() => avatarService.uploadAvatar(any()))
        .thenAnswer((_) async => 'path-2');
    feed.emit(_profile('path-1'));
    await pumpAvatar(tester);
    await tester.pump();

    feed.stored = _profile('path-2');
    await containerOf(tester)
        .read(avatarEditProvider.notifier)
        .uploadAvatar(File('a.png'));
    await tester.pump();

    expect(displayedAvatarUrl(tester), 'path-2');
  });

  testWidgets(
      'shows no avatar after a delete even if the stream emitted '
      'nothing', (tester) async {
    when(() => avatarService.deleteAvatar()).thenAnswer((_) async {});
    feed.emit(_profile('path-1'));
    await pumpAvatar(tester);
    await tester.pump();

    feed.stored = _profile(null);
    await containerOf(tester).read(avatarEditProvider.notifier).deleteAvatar();
    await tester.pump();

    expect(displayedAvatarUrl(tester), isNull);
  });

  testWidgets('keeps the profile avatar and shows a snackbar when it fails',
      (tester) async {
    when(() => avatarService.uploadAvatar(any()))
        .thenThrow(Exception('network'));
    feed.emit(_profile('path-1'));
    await pumpAvatar(tester);
    await tester.pump();

    await containerOf(tester)
        .read(avatarEditProvider.notifier)
        .uploadAvatar(File('a.png'));
    await tester.pump();

    expect(
      find.text("Erreur lors du chargement de l'image"),
      findsOneWidget,
    );
    expect(displayedAvatarUrl(tester), 'path-1');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets(
      'an upload finishing after Settings was left shows up when it is '
      'opened again', (tester) async {
    final upload = Completer<String>();
    when(() => avatarService.uploadAvatar(any()))
        .thenAnswer((_) => upload.future);
    feed.emit(_profile('path-1'));
    await pumpAvatar(tester);
    await tester.pump();

    unawaited(
      containerOf(tester)
          .read(avatarEditProvider.notifier)
          .uploadAvatar(File('a.png')),
    );
    await tester.pump();

    // Leave Settings: the notifier is disposed, the upload goes on.
    await pumpAvatar(tester, visible: false);
    await tester.pump();

    // The upload ends and the profile stream emits the new avatar.
    upload.complete('path-2');
    feed.emit(_profile('path-2'));
    await tester.pump();

    // Open Settings again: no upload state left, the stream gives the url.
    await pumpAvatar(tester);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(displayedAvatarUrl(tester), 'path-2');
  });
}
