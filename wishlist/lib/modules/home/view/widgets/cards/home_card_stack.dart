import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/home/cards/home_card_actions.dart';
import 'package:wishlist/modules/home/cards/home_card_candidate.dart';
import 'package:wishlist/modules/home/cards/home_cards_provider.dart';
import 'package:wishlist/modules/home/view/widgets/cards/home_card_view.dart';
import 'package:wishlist/shared/infra/clock_provider.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/utils/app_snackbar.dart';

/// The cards of the moment of the home screen, between the header and the
/// rest. Shows nothing while the cards load for the first time and when they
/// cannot be loaded; while they reload it keeps the previous ones, so that the
/// pile never blinks. The cards swiped away and not sent yet are left out.
class HomeCardsSlot extends ConsumerStatefulWidget {
  const HomeCardsSlot({super.key});

  @override
  ConsumerState<HomeCardsSlot> createState() => _HomeCardsSlotState();
}

class _HomeCardsSlotState extends ConsumerState<HomeCardsSlot> {
  /// An error snack-bar of this slot is on screen (or about to be): several
  /// sends failing at once (offline) tell the user once, not once per card.
  var _errorVisible = false;

  @override
  Widget build(BuildContext context) {
    // `valueOrNull` keeps the previous value while reloading
    final cards = ref.watch(homeCardsProvider).valueOrNull;
    final removed = ref.watch(homeCardActionsProvider);
    // A card sent and gone from the reload is not filtered any more: it shows
    // again when it comes back (the next day, the next reminder step).
    ref
      ..listen(homeCardsProvider, (_, next) {
        final loaded = next.valueOrNull;
        if (loaded != null) {
          ref.read(homeCardActionsProvider.notifier).release({
            for (final card in loaded) card.stateKey,
          });
        }
      })
      // A send that failed: the card is back, the user must know
      ..listen(homeCardSendFailureProvider, (_, failure) {
        if (failure != null && !_errorVisible) {
          _errorVisible = true;
          showGenericError(
            context,
            error: failure.error,
            onClosed: () => _errorVisible = false,
          );
        }
      });
    final visible = [
      for (final card in cards ?? const <HomeCardCandidate>[])
        if (!removed.contains(card.stateKey)) card,
    ];
    // The height animates when the last card goes, when an undo brings one
    // back, and when the next card is not as tall as the one it replaces.
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: visible.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: HomeCardStack(cards: visible),
            ),
    );
  }
}

/// The first of [cards] on top, its edges below and the next two cards behind.
/// The top card can be swiped (right: later, left: hide) unless it cannot be
/// hidden; the cross hides it as well.
class HomeCardStack extends ConsumerStatefulWidget {
  const HomeCardStack({super.key, required this.cards});

  final List<HomeCardCandidate> cards;

  @override
  ConsumerState<HomeCardStack> createState() => _HomeCardStackState();
}

class _HomeCardStackState extends ConsumerState<HomeCardStack> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _recordTop);
    _recordTop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Back in front after another screen was on top of the home
    _recordTop();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HomeCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _recordTop();
  }

  /// Only the top card is in front of the user, and only while the home is the
  /// screen on top and the app is in front (a live event reloads the cards
  /// behind another screen or in the background). The notifier records each
  /// key once.
  void _recordTop() {
    final top = widget.cards.firstOrNull;
    if (top == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isInFront) {
        ref.read(homeCardActionsProvider.notifier).recordShown(top.stateKey);
      }
    });
    // Nothing else may ask for a frame (the app was just resumed)
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool get _isInFront {
    final state = WidgetsBinding.instance.lifecycleState;
    return (ModalRoute.of(context)?.isCurrent ?? true) &&
        (state == null || state == AppLifecycleState.resumed);
  }

  void _swipe(HomeCardCandidate card, HomeCardSwipe swipe) {
    final l10n = context.l10n;
    final actions = ref.read(homeCardActionsProvider.notifier);
    final key = card.stateKey;
    // A screen reader user needs more than 4 s: the snack-bar stays until
    // dismissed, and the card is sent when leaving or on the app lifecycle.
    final keepOpen = MediaQuery.of(context).accessibleNavigation;
    // Already off the screen (a double tap on the cross): the first swipe has
    // its snack-bar, a second one would have an "Undo" that does nothing.
    if (!actions.swipe(card, swipe, autoCommit: !keepOpen)) {
      return;
    }
    final close = showAppSnackBar(
      context,
      swipe == HomeCardSwipe.hide
          ? l10n.homeCardHidden
          : l10n.homeCardPostponed(actions.laterDays),
      type: SnackBarType.success,
      // Explicit: the undo delay does not depend on the default of the widget
      // ignore: avoid_redundant_argument_values
      duration: homeCardUndoDuration,
      autoClose: !keepOpen,
      actionLabel: l10n.cancelButton,
      onAction: () => actions.undo(key),
      // The card is sent when the snack-bar closes, so "Undo" is never offered
      // once it was sent.
      onClosed: () => actions.commit(key),
    );
    // Anything else that sends the card (lifecycle, leaving) closes it too
    actions.attachCloser(key, close);
  }

  /// Whether swiping right makes sense: a card closed for good (an alert, the
  /// optional onboarding steps) is not brought back tomorrow, it is hidden. Nor
  /// is a card that is gone by the day it would come back (the event is today,
  /// the window ends before).
  bool _canPostpone(HomeCardCandidate card) {
    final lastDay = card.lastDay;
    if (lastDay != null) {
      final now = ref.read(clockProvider)();
      final comesBack = DateTime(
        now.year,
        now.month,
        now.day + ref.read(homeCardActionsProvider.notifier).laterDays,
      );
      if (comesBack.isAfter(lastDay)) {
        return false;
      }
    }
    return switch (card.content) {
      BookedWishRemoved() => false,
      Onboarding(:final step) =>
        step != OnboardingStep.birthday && step != OnboardingStep.photo,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;
    final top = cards.first;
    final behind = (cards.length - 1).clamp(0, 2);

    final view = HomeCardView(
      card: top,
      flat: top.dismissable,
      onHide: () => _swipe(top, HomeCardSwipe.hide),
    );

    final l10n = context.l10n;
    final canPostpone = _canPostpone(top);
    final hideBackground = _SwipeBackground(
      color: AppColors.gainsboro,
      icon: Icons.close,
      label: l10n.homeCardHide,
      alignment: Alignment.centerRight,
    );

    return Column(
      children: [
        if (top.dismissable)
          // One rounded slot: the card slides in it, the background is
          // revealed in it, and the outline is drawn over both so that it
          // stays continuous (the flat card has none of its own).
          Semantics(
            // The swipes, for those who cannot do the gesture
            customSemanticsActions: {
              if (canPostpone)
                CustomSemanticsAction(label: l10n.homeCardLater): () =>
                    _swipe(top, HomeCardSwipe.later),
              CustomSemanticsAction(label: l10n.homeCardHide): () =>
                  _swipe(top, HomeCardSwipe.hide),
            },
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(homeCardRadius),
                border: homeCardBorderColor(top.tone) == null
                    ? null
                    : Border.all(color: homeCardBorderColor(top.tone)!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(homeCardRadius),
                child: Dismissible(
                  // One element per card: the next card never inherits the drag
                  key: ValueKey(top.stateKey),
                  // No shrinking after the slide: the next card takes the slot
                  // as soon as this one is gone
                  resizeDuration: null,
                  direction: canPostpone
                      ? DismissDirection.horizontal
                      : DismissDirection.endToStart,
                  onDismissed: (direction) => _swipe(
                    top,
                    direction == DismissDirection.startToEnd
                        ? HomeCardSwipe.later
                        : HomeCardSwipe.hide,
                  ),
                  // With a single direction `background` is what is shown
                  background: canPostpone
                      ? _SwipeBackground(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          icon: Icons.schedule,
                          label: l10n.homeCardLater,
                          alignment: Alignment.centerLeft,
                        )
                      : hideBackground,
                  secondaryBackground: canPostpone ? hideBackground : null,
                  child: view,
                ),
              ),
            ),
          )
        else
          view,
        if (behind >= 1) const HomeCardEdge(height: 8, inset: 12),
        if (behind >= 2) const HomeCardEdge(height: 7, inset: 26),
      ],
    );
  }
}

/// The edge of a card that waits behind the top one.
@visibleForTesting
class HomeCardEdge extends StatelessWidget {
  const HomeCardEdge({super.key, required this.height, required this.inset});

  final double height;
  final double inset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            left: BorderSide(color: AppColors.gainsboro),
            right: BorderSide(color: AppColors.gainsboro),
            bottom: BorderSide(color: AppColors.gainsboro),
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
        ),
        child: SizedBox(height: height, width: double.infinity),
      ),
    );
  }
}

/// What is revealed under the card while it slides: the icon and the word of
/// the swipe.
class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.darkGrey),
              const Gap(8),
              Text(
                label,
                style: AppTextStyles.smaller.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
