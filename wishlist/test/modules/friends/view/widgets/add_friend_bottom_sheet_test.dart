import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishlist/l10n/arb/app_localizations_fr.dart';
import 'package:wishlist/modules/friends/view/infra/search_notifier.dart';
import 'package:wishlist/modules/friends/view/widgets/add_friend_bottom_sheet.dart';
import 'package:wishlist/shared/models/app_user.dart';

import '../../../../pump_app.dart';

class _TestSearchNotifier extends SearchNotifier {
  _TestSearchNotifier(super.ref);

  // ignore: use_setters_to_change_properties
  void emit(AsyncValue<IList<AppUser>> value) => state = value;
}

void main() {
  testWidgets('shows a single error snackbar however often it rebuilds',
      (tester) async {
    late _TestSearchNotifier notifier;
    await tester.pumpApp(
      const AddFriendBottomSheet(),
      overrides: [
        searchProvider.overrideWith(
          (ref) => notifier = _TestSearchNotifier(ref),
        ),
      ],
    );

    final message = AppLocalizationsFr().genericError;
    notifier.emit(AsyncValue.error(Exception('boom'), StackTrace.empty));
    await tester.pump();
    await tester.pump();
    expect(find.text(message), findsOneWidget);

    // Still failing: more rebuilds, no second snackbar
    notifier.emit(AsyncValue.error(Exception('boom'), StackTrace.empty));
    await tester.pump();
    await tester.pump();
    expect(find.text(message), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
  });
}
