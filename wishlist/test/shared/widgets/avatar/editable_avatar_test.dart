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
  Profile? _latest;

  Stream<Profile?> get stream => Stream.multi((listener) {
        if (_latest != null) {
          listener.add(_latest);
        }
        final subscription = _controller.stream.listen(listener.add);
        listener.onCancel = subscription.cancel;
      });

  void emit(Profile? profile) {
    _latest = profile;
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

  testWidgets('shows a spinner while an upload is running', (tester) async {
    final upload = Completer<String>();
    when(() => avatarService.uploadAvatar(any()))
        .thenAnswer((_) => upload.future);
    feed.emit(_profile('path-1'));
    await pumpAvatar(tester);
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(EditableAvatar)),
    );
    unawaited(
      container.read(avatarEditProvider.notifier).uploadAvatar(File('a.png')),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(AppAvatar), findsNothing);

    upload.complete('path-2');
    await tester.pump();

    expect(displayedAvatarUrl(tester), 'path-1');
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

    final container = ProviderScope.containerOf(
      tester.element(find.byType(EditableAvatar)),
    );
    unawaited(
      container.read(avatarEditProvider.notifier).uploadAvatar(File('a.png')),
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
