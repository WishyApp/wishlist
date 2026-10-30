import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
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

/// The first of [cards] on top, the next two cards behind it, their bottom
/// showing under it. The top card can be swiped (right: later, left: hide)
/// unless it cannot be hidden; the cross hides it as well.
class HomeCardStack extends ConsumerStatefulWidget {
  const HomeCardStack({super.key, required this.cards});

  final List<HomeCardCandidate> cards;

  @override
  ConsumerState<HomeCardStack> createState() => _HomeCardStackState();
}

class _HomeCardStackState extends ConsumerState<HomeCardStack> {
  late final AppLifecycleListener _lifecycle;

  /// The last card swiped away: when it comes back on top ("Undo", a failed
  /// send), it comes back from the side it left by.
  ({String key, HomeCardSwipe swipe})? _lastSwiped;

  /// The side the top card comes in from, if it is the last card swiped away.
  HomeCardSwipe? _enterFrom;

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
    final top = widget.cards.first.stateKey;
    if (top != oldWidget.cards.first.stateKey) {
      final last = _lastSwiped;
      _enterFrom = last?.key == top ? last!.swipe : null;
      if (_enterFrom != null) {
        _lastSwiped = null;
      }
    }
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
    _lastSwiped = (key: key, swipe: swipe);
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
    final l10n = context.l10n;
    final canPostpone = _canPostpone(top);

    final view = HomeCardView(
      card: top,
      onHide: () => _swipe(top, HomeCardSwipe.hide),
    );

    return _SwipePile(
      // One state per card: the next card never inherits the drag
      key: ValueKey(top.stateKey),
      directions: {
        if (top.dismissable) HomeCardSwipe.hide,
        if (top.dismissable && canPostpone) HomeCardSwipe.later,
      },
      enterFrom: _enterFrom,
      onSwiped: (swipe) => _swipe(top, swipe),
      behind: [
        for (final card in cards.skip(1).take(_behindRest.length))
          HomeCardView(card: card, onHide: () {}),
      ],
      top: top.dismissable
          ? Semantics(
              // The swipes, for those who cannot do the gesture
              customSemanticsActions: {
                if (canPostpone)
                  CustomSemanticsAction(label: l10n.homeCardLater): () =>
                      _swipe(top, HomeCardSwipe.later),
                CustomSemanticsAction(label: l10n.homeCardHide): () =>
                    _swipe(top, HomeCardSwipe.hide),
              },
              child: view,
            )
          : view,
    );
  }
}

/// How far the top card tilts once dragged by its whole width (it leaves the
/// screen a bit further). None when the system asks for less motion.
const _maxTilt = 8 * pi / 180;

/// Where the top card turns around: under its middle, as a card held by the
/// bottom.
const _tiltPivot = Alignment(0, 1.8);

/// The cards behind at rest, the closest first: their scale and how far their
/// bottom shows under the top card.
const _behindRest = [(scale: 0.94, drop: 10.0), (scale: 0.88, drop: 19.0)];

/// The part of the width past which a released card leaves (as `Dismissible`).
const _leaveThreshold = 0.4;

/// A release faster than this (px/s) throws the card away (as `Dismissible`).
const _flingVelocity = 700.0;

/// The travel, in widths, at which the next card has taken the top place.
const _fullTravel = 0.6;

/// Where a leaving card ends, in widths: out of the screen, tilt included.
const _outside = 1.5;

/// How far, in widths, a card can be pulled to a side it cannot go to.
const _stretch = 0.12;

/// The top card and the cards behind it. The top card follows the finger and
/// tilts; the cards behind move up and grow as it goes. Released far or fast
/// enough to one of [directions], it leaves the screen, then [onSwiped] tells
/// it; otherwise it springs back. Pulled to a side it cannot go to, it resists
/// and comes back.
class _SwipePile extends StatefulWidget {
  const _SwipePile({
    super.key,
    required this.top,
    required this.behind,
    required this.directions,
    required this.onSwiped,
    this.enterFrom,
  });

  final Widget top;

  /// The cards behind, the closest first.
  final List<Widget> behind;

  /// The swipes the top card allows: none, it does not move.
  final Set<HomeCardSwipe> directions;

  final ValueChanged<HomeCardSwipe> onSwiped;

  /// The top card comes in from this side (it was swiped away by it).
  final HomeCardSwipe? enterFrom;

  @override
  State<_SwipePile> createState() => _SwipePileState();
}

class _SwipePileState extends State<_SwipePile>
    with SingleTickerProviderStateMixin {
  /// Where the top card is, in widths: right is positive (later).
  late final AnimationController _offset;

  /// Where the finger took the card, in widths, before the resistance of a
  /// forbidden side.
  var _drag = 0.0;

  var _leaving = false;

  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 400,
    ratio: 0.8,
  );

  @override
  void initState() {
    super.initState();
    _offset = AnimationController.unbounded(
      vsync: this,
      value: switch (widget.enterFrom) {
        HomeCardSwipe.later => _outside,
        HomeCardSwipe.hide => -_outside,
        null => 0,
      },
    );
    if (widget.enterFrom != null) {
      _offset.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  static HomeCardSwipe _sideOf(double value) =>
      value > 0 ? HomeCardSwipe.later : HomeCardSwipe.hide;

  bool _allows(double value) =>
      value != 0 && widget.directions.contains(_sideOf(value));

  /// The position for a drag of [drag]: free to an allowed side, stretched
  /// up to [_stretch] to the other.
  double _resisted(double drag) {
    if (drag == 0 || _allows(drag)) {
      return drag;
    }
    return drag.sign * _stretch * (1 - 1 / (1 + drag.abs() / _stretch));
  }

  /// The drag that gives [value]: the card is taken back where it is.
  double _unresisted(double value) {
    if (value == 0 || _allows(value)) {
      return value;
    }
    final ratio = (value.abs() / _stretch).clamp(0.0, 0.99);
    return value.sign * _stretch * (1 / (1 - ratio) - 1);
  }

  void _onStart(DragStartDetails details) {
    if (_leaving) {
      return;
    }
    _offset.stop();
    _drag = _unresisted(_offset.value);
  }

  void _onUpdate(DragUpdateDetails details, double width) {
    if (_leaving) {
      return;
    }
    _drag += details.primaryDelta! / width;
    _offset.value = _resisted(_drag);
  }

  void _onEnd(DragEndDetails details, double width) {
    if (_leaving) {
      return;
    }
    final value = _offset.value;
    final velocity = details.primaryVelocity ?? 0;
    final flung = velocity.abs() > _flingVelocity &&
        velocity.sign == value.sign &&
        _allows(velocity);
    if (_allows(value) && (value.abs() > _leaveThreshold || flung)) {
      _leave(_sideOf(value));
    } else {
      _offset.animateWith(
        SpringSimulation(_spring, value, 0, velocity / width),
      );
    }
  }

  Future<void> _leave(HomeCardSwipe side) async {
    _leaving = true;
    await _offset.animateTo(
      side == HomeCardSwipe.later ? _outside : -_outside,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    if (mounted) {
      widget.onSwiped(side);
    }
  }

  @override
  Widget build(BuildContext context) {
    final behind = widget.behind;
    final still = MediaQuery.disableAnimationsOf(context);
    final pile = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return AnimatedBuilder(
          animation: _offset,
          builder: (context, _) {
            final value = _offset.value;
            // The cards behind only move up for a side the card can go to
            final progress = _allows(value)
                ? (value.abs() / _fullTravel).clamp(0.0, 1.0)
                : 0.0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = behind.length - 1; i >= 0; i--)
                  Positioned.fill(
                    child: _BehindCard(
                      depth: i,
                      progress: progress,
                      child: behind[i],
                    ),
                  ),
                Transform.translate(
                  offset: Offset(value * width, 0),
                  child: Transform.rotate(
                    angle: still ? 0 : value * _maxTilt,
                    alignment: _tiltPivot,
                    child: _TopCard(
                      offset: value,
                      side: _allows(value) ? _sideOf(value) : null,
                      child: widget.top,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    return Padding(
      // The bottom of the cards behind, under the top card
      padding: EdgeInsets.only(
        bottom: behind.isEmpty ? 0 : _behindRest[behind.length - 1].drop,
      ),
      child: widget.directions.isEmpty
          ? pile
          : LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                onHorizontalDragStart: _onStart,
                onHorizontalDragUpdate: (details) =>
                    _onUpdate(details, constraints.maxWidth),
                onHorizontalDragEnd: (details) =>
                    _onEnd(details, constraints.maxWidth),
                onHorizontalDragCancel: () =>
                    _onEnd(DragEndDetails(), constraints.maxWidth),
                child: pile,
              ),
            ),
    );
  }
}

/// The top card: a shadow while it moves, and the swipe it would do written
/// on it once it heads to one [side].
class _TopCard extends StatelessWidget {
  const _TopCard({
    required this.offset,
    required this.side,
    required this.child,
  });

  /// Where the card is, in widths.
  final double offset;
  final HomeCardSwipe? side;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lift = (offset.abs() * 2).clamp(0.0, 1.0);
    // Fully there after a third of the width
    final shown = side == null ? 0.0 : (offset.abs() / 0.3).clamp(0.0, 1.0);
    final radius = BorderRadius.circular(homeCardRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          if (lift > 0)
            BoxShadow(
              color: AppColors.darkGrey.withValues(alpha: 0.15 * lift),
              offset: Offset(0, 10 * lift),
              blurRadius: 24 * lift,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            child,
            if (side != null && shown > 0) ...[
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    // Hiding is for good: the stronger colour
                    color: side == HomeCardSwipe.hide
                        ? AppColors.primary.withValues(alpha: 0.18 * shown)
                        : AppColors.darkGrey.withValues(alpha: 0.10 * shown),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: side == HomeCardSwipe.later ? 12 : null,
                right: side == HomeCardSwipe.hide ? 12 : null,
                child: Opacity(
                  opacity: shown,
                  child: side == HomeCardSwipe.later
                      ? _SwipeStamp(
                          icon: Icons.schedule,
                          label: l10n.homeCardLater,
                        )
                      : _SwipeStamp(
                          icon: Icons.close,
                          label: l10n.homeCardHide,
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A card waiting behind the top one, cut to its size: smaller and lower the
/// further it is ([depth] 0 is the next one), it takes the place of the card
/// in front of it as [progress] goes from 0 to 1.
class _BehindCard extends StatelessWidget {
  const _BehindCard({
    required this.depth,
    required this.progress,
    required this.child,
  });

  final int depth;
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final from = _behindRest[depth];
    final to = depth == 0 ? (scale: 1.0, drop: 0.0) : _behindRest[depth - 1];
    final scale = lerpDouble(from.scale, to.scale, progress)!;
    final drop = lerpDouble(from.drop, to.drop, progress)!;
    // A hint of depth: the further, the darker
    final shade = lerpDouble(0.04 * (depth + 1), 0.04 * depth, progress)!;
    final radius = BorderRadius.circular(homeCardRadius);
    return Transform(
      alignment: Alignment.bottomCenter,
      transform: Matrix4.diagonal3Values(scale, scale, 1)
        ..setTranslationRaw(0, drop, 0),
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x142C2C2C),
                  offset: Offset(0, 4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Its own height, at least the one of the top card: the
                  // top of it shows when it comes up
                  OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: double.infinity,
                    child: child,
                  ),
                  ColoredBox(
                    color: AppColors.darkGrey.withValues(alpha: shade),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the swipe does, written on the top card while it is dragged.
class _SwipeStamp extends StatelessWidget {
  const _SwipeStamp({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F2C2C2C),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.darkGrey),
            const Gap(6),
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
    );
  }
}
