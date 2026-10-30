import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
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

class _HomeCardsSlotState extends ConsumerState<HomeCardsSlot>
    with SingleTickerProviderStateMixin {
  /// An error snack-bar of this slot is on screen (or about to be): several
  /// sends failing at once (offline) tell the user once, not once per card.
  var _errorVisible = false;

  /// The card brought back by "Undo" and the side it left by: it comes back
  /// from there. Read by the next build only: a card back for another reason
  /// (a reload, the next day) just shows. Kept here: the stack is gone while
  /// no card is left.
  ({String key, HomeCardSwipe swipe})? _undone;

  /// Whether the slot was empty at the last build.
  bool? _wasEmpty;

  /// The slot grows when cards come, shrinks when the last one goes. From
  /// one card to the next, the pile animates its own height: the slot
  /// follows it exactly.
  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: 1,
  );

  /// The height the slot had when it started to grow or shrink.
  double? _appearFrom;

  /// The height of the slot as last drawn.
  var _height = 0.0;

  @override
  void dispose() {
    _appear.dispose();
    super.dispose();
  }

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
    final empty = visible.isEmpty;
    // Not on the first build: the slot does not grow when the home opens
    if (_wasEmpty != null && _wasEmpty != empty) {
      _appearFrom = _height;
      _appear.forward(from: 0);
    }
    _wasEmpty = empty;
    final returning = _undone;
    _undone = null;
    return AnimatedBuilder(
      animation: _appear,
      builder: (context, child) => _ResizedFrom(
        from: _appearFrom,
        progress: Curves.easeInOut.transform(_appear.value),
        // Not a state change: only read when the slot starts to resize
        onHeight: (height) => _height = height,
        child: child,
      ),
      child: empty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: HomeCardStack(
                cards: visible,
                returning: returning,
                onUndo: (key, swipe) =>
                    setState(() => _undone = (key: key, swipe: swipe)),
              ),
            ),
    );
  }
}

/// The first of [cards] on top, the next two cards behind it, their bottom
/// showing under it. The top card can be swiped (towards the end of the text,
/// right in French: later; towards its start: hide) unless it cannot be
/// hidden; the cross hides it as well.
class HomeCardStack extends ConsumerStatefulWidget {
  const HomeCardStack({
    super.key,
    required this.cards,
    this.returning,
    this.onUndo,
  });

  final List<HomeCardCandidate> cards;

  /// A card just brought back by "Undo": on top, it comes in from the side
  /// it left by.
  final ({String key, HomeCardSwipe swipe})? returning;

  /// "Undo" was tapped for a card swiped away to this side.
  final void Function(String key, HomeCardSwipe swipe)? onUndo;

  @override
  ConsumerState<HomeCardStack> createState() => _HomeCardStackState();
}

class _HomeCardStackState extends ConsumerState<HomeCardStack> {
  late final AppLifecycleListener _lifecycle;

  /// The height of the top card as last drawn: the next one on top starts
  /// from it.
  double? _topHeight;

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
      onAction: () {
        widget.onUndo?.call(key, swipe);
        actions.undo(key);
      },
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
    final returning = widget.returning;

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
      enterFrom: returning?.key == top.stateKey ? returning!.swipe : null,
      fromHeight: _topHeight,
      // Not a state change: only read by the next pile
      onHeight: (height) => _topHeight = height,
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
/// and comes back. Later is towards the end of the text, as `Dismissible`'s
/// `startToEnd`.
class _SwipePile extends StatefulWidget {
  const _SwipePile({
    super.key,
    required this.top,
    required this.behind,
    required this.directions,
    required this.onSwiped,
    this.enterFrom,
    this.fromHeight,
    required this.onHeight,
  });

  final Widget top;

  /// The cards behind, the closest first.
  final List<Widget> behind;

  /// The swipes the top card allows: none, it does not move.
  final Set<HomeCardSwipe> directions;

  /// The card left by this side. If it was already swiped away (the cross
  /// just before), it stays out until the next build takes it away.
  final ValueChanged<HomeCardSwipe> onSwiped;

  /// The top card comes in from this side (it was swiped away by it). Read
  /// when the pile is created.
  final HomeCardSwipe? enterFrom;

  /// The height of the card that was on top before: the top card starts at
  /// it and goes to its own, so that nothing jumps when one replaces the
  /// other. Read when the pile is created, as [enterFrom].
  final double? fromHeight;

  /// The top card was laid out at this height.
  final ValueChanged<double> onHeight;

  @override
  State<_SwipePile> createState() => _SwipePileState();
}

class _SwipePileState extends State<_SwipePile> with TickerProviderStateMixin {
  /// Where the top card is, in widths: towards the end of the text is
  /// positive (later).
  late final AnimationController _offset;

  /// From [_SwipePile.fromHeight] (0) to the card's own height (1).
  late final AnimationController _resize;

  late final double? _fromHeight = widget.fromHeight;

  /// Where the finger took the card, in widths, before the resistance of a
  /// forbidden side.
  var _drag = 0.0;

  /// A drag was taken: only its own update, end or cancel move the card.
  var _dragging = false;

  /// The system took the pointer back (a call, a system gesture): the drag
  /// ends as if released, but the user did not let the card go.
  var _pointerCancelled = false;

  /// The card comes back ("Undo"): a drag now would start from the side and
  /// leave again at once.
  var _entering = false;

  /// The card goes: no drag nor tap any more, its swipe is decided.
  var _leaving = false;

  /// Back to the middle without going past it: past it, the other side's
  /// stamp would flash and the cards behind would jump.
  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 400,
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
    _resize = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: _fromHeight == null ? 1 : 0,
    );
  }

  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    // Less motion: in place at once
    if (MediaQuery.disableAnimationsOf(context)) {
      _offset.value = 0;
      _resize.value = 1;
      return;
    }
    if (widget.enterFrom != null) {
      _entering = true;
      _offset
          .animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          )
          .whenCompleteOrCancel(() => _entering = false);
    }
    _resize.forward();
  }

  @override
  void didUpdateWidget(_SwipePile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The card cannot be swiped any more (a reload): its drag detector goes
    // without an end, the card would stay where the finger left it.
    if (widget.directions.isEmpty && _dragging) {
      _dragging = false;
      _settle();
    }
  }

  @override
  void dispose() {
    _offset.dispose();
    _resize.dispose();
    super.dispose();
  }

  /// From the text direction to the screen: -1 when right to left.
  double get _screenSign =>
      Directionality.of(context) == TextDirection.rtl ? -1 : 1;

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
    if (_leaving || _entering) {
      return;
    }
    _dragging = true;
    _offset.stop();
    _drag = _unresisted(_offset.value);
  }

  void _onUpdate(DragUpdateDetails details, double width) {
    if (!_dragging) {
      return;
    }
    _drag += details.primaryDelta! * _screenSign / width;
    _offset.value = _resisted(_drag);
  }

  void _onEnd(DragEndDetails details) {
    if (!_dragging) {
      return;
    }
    _dragging = false;
    if (_pointerCancelled) {
      _settle();
      return;
    }
    final value = _offset.value;
    final velocity = (details.primaryVelocity ?? 0) * _screenSign;
    final flung = velocity.abs() > _flingVelocity &&
        velocity.sign == value.sign &&
        _allows(velocity);
    if (_allows(value) && (value.abs() > _leaveThreshold || flung)) {
      _leave(_sideOf(value));
    } else {
      _settle();
    }
  }

  /// The touch was taken by something else before it became a drag (the page
  /// scrolls): the card does not leave, whatever its position.
  void _onCancel() {
    if (!_dragging) {
      return;
    }
    _dragging = false;
    _settle();
  }

  /// Back to the middle. From a standstill: with the speed of the finger, a
  /// card thrown to a forbidden side would go far past its stretch.
  void _settle() =>
      _offset.animateWith(SpringSimulation(_spring, _offset.value, 0, 0));

  Future<void> _leave(HomeCardSwipe side) async {
    setState(() => _leaving = true);
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
    final sign = _screenSign;
    final pile = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return AnimatedBuilder(
          animation: Listenable.merge([_offset, _resize]),
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
                  offset: Offset(value * width * sign, 0),
                  child: Transform.rotate(
                    angle: still ? 0 : value * sign * _maxTilt,
                    alignment: _tiltPivot,
                    child: IgnorePointer(
                      ignoring: _leaving,
                      child: _TopCard(
                        offset: value,
                        side: _allows(value) ? _sideOf(value) : null,
                        child: _ResizedFrom(
                          from: _fromHeight,
                          progress: Curves.easeOutCubic.transform(
                            _resize.value,
                          ),
                          onHeight: widget.onHeight,
                          child: widget.top,
                        ),
                      ),
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
              builder: (context, constraints) => Listener(
                // Before the drag recognizer, which ends the drag on it
                onPointerDown: (_) => _pointerCancelled = false,
                onPointerCancel: (_) => _pointerCancelled = true,
                child: GestureDetector(
                  onHorizontalDragStart: _onStart,
                  onHorizontalDragUpdate: (details) =>
                      _onUpdate(details, constraints.maxWidth),
                  onHorizontalDragEnd: _onEnd,
                  onHorizontalDragCancel: _onCancel,
                  child: pile,
                ),
              ),
            ),
    );
  }
}

/// Its child at a height going from [from] to the child's own as [progress]
/// goes from 0 to 1: taller than its own, the child is stretched (the
/// background of a card fills it); shorter, it is cut at the bottom. For the
/// top card, as a card behind it is drawn, so that one taking the top place
/// does not change; for the slot, as it grows or shrinks.
class _ResizedFrom extends SingleChildRenderObjectWidget {
  const _ResizedFrom({
    required this.from,
    required this.progress,
    required this.onHeight,
    required super.child,
  });

  final double? from;
  final double progress;
  final ValueChanged<double> onHeight;

  @override
  _RenderResizedFrom createRenderObject(BuildContext context) =>
      _RenderResizedFrom(from: from, progress: progress, onHeight: onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderResizedFrom renderObject,
  ) {
    renderObject
      ..from = from
      ..progress = progress
      ..onHeight = onHeight;
  }
}

class _RenderResizedFrom extends RenderProxyBox {
  _RenderResizedFrom({
    required double? from,
    required double progress,
    required this.onHeight,
  })  : _from = from,
        _progress = progress;

  ValueChanged<double> onHeight;

  double? get from => _from;
  double? _from;
  set from(double? value) {
    if (value != _from) {
      _from = value;
      markNeedsLayout();
    }
  }

  double get progress => _progress;
  double _progress;
  set progress(double value) {
    if (value != _progress) {
      _progress = value;
      markNeedsLayout();
    }
  }

  /// The height drawn for a child of height [own].
  double _heightFor(double own) {
    final from = _from;
    return from == null || _progress >= 1
        ? own
        : lerpDouble(from, own, _progress)!;
  }

  @override
  void performLayout() {
    final child = this.child!;
    final free = constraints.copyWith(minHeight: 0);
    child.layout(free, parentUsesSize: true);
    final own = child.size.height;
    final height = _heightFor(own);
    if (height > own) {
      child.layout(
        free.copyWith(minHeight: min(height, constraints.maxHeight)),
        parentUsesSize: true,
      );
    }
    size = constraints.constrain(Size(child.size.width, height));
    onHeight(size.height);
  }

  final _clip = LayerHandle<ClipRectLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child != null && child.size.height > size.height) {
      _clip.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        super.paint,
        oldLayer: _clip.layer,
      );
    } else {
      _clip.layer = null;
      super.paint(context, offset);
    }
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final own = child!.getDryLayout(constraints.copyWith(minHeight: 0));
    return constraints.constrain(Size(own.width, _heightFor(own.height)));
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _heightFor(super.computeMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _heightFor(super.computeMaxIntrinsicHeight(width));
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
              // On the side the card comes from, as the text reads
              PositionedDirectional(
                top: 12,
                start: side == HomeCardSwipe.later ? 12 : null,
                end: side == HomeCardSwipe.hide ? 12 : null,
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
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkGrey.withValues(alpha: 0.08),
                  offset: const Offset(0, 4),
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
        boxShadow: [
          BoxShadow(
            color: AppColors.darkGrey.withValues(alpha: 0.12),
            offset: const Offset(0, 2),
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
