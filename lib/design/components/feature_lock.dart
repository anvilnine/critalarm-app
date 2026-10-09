import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/design/components/pro_badge.dart';
import 'package:flutter/material.dart';

/// What a screen reader says for a locked option: its name, then that it
/// is locked, then the plan that unlocks it.
String featureLockSpoken({
  required String name,
  required String lockedWord,
  required String? planWord,
}) => [
  name,
  lockedWord,
  ?planWord,
].where((part) => part.trim().isNotEmpty).join(', ');

/// Where the corner badge of a [FeatureLock] sits.
enum FeatureLockSeat {
  /// On the corner, over the child. For a child with nothing to read in
  /// that corner, such as a wide button with its label in the middle.
  corner,

  /// Above the child's top edge, reaching down over it by
  /// [FeatureLock.badgeTuck] and no more, so it covers no label and no
  /// picture. The caller leaves [FeatureLock.badgeRoomAbove] free over the
  /// child.
  above,
}

/// The one way the app draws something a plan would unlock.
///
/// It wraps any option and draws it from a [FeatureDecision]:
///
/// - Open, confirming or unread: the child, untouched. A purchase being
///   confirmed and a plan that could not be read both count as usable, so
///   neither draws a lock.
/// - Not offered: the child, untouched, with no badge and nothing to tap.
///   There is nothing to sell, so the caller says in its own words that
///   the feature is not available here.
/// - Locked: the child at full colour with the plan badge on its corner, a
///   lock glyph and [planWord]. Nothing is dimmed or blurred. A tap goes to
///   [onLockedTap] and never to the child. Where the corner holds a label
///   or a picture, [FeatureLockSeat.above] seats the badge over the edge
///   instead.
///
/// It knows no feature, no paywall and no strings. A wrapper on the feature
/// side reads the decision, listens for it changing and passes the words
/// in.
///
/// [FeatureLock.scope] is for a child that has a place of its own for the
/// badge and a button of its own for the paywall: it draws nothing and
/// takes no tap. The child puts a [FeatureLockBadge] where it wants it and
/// calls [FeatureLockScope.unlock].
class FeatureLock extends StatelessWidget {
  const FeatureLock({
    required this.decision,
    required this.planWord,
    required this.lockedWord,
    required this.child,
    this.name,
    this.hint,
    this.onLockedTap,
    this.onUnlock,
    this.badgeAlignment = AlignmentDirectional.topEnd,
    this.badgeOverhang = 6,
    this.badgeSeat = FeatureLockSeat.corner,
    this.drawsBadge = true,
    super.key,
  }) : _isScopeOnly = false;

  const FeatureLock.scope({
    required this.decision,
    required this.planWord,
    required this.child,
    this.onUnlock,
    super.key,
  }) : lockedWord = '',
       name = null,
       hint = null,
       onLockedTap = null,
       badgeAlignment = AlignmentDirectional.topEnd,
       badgeOverhang = 0,
       badgeSeat = FeatureLockSeat.corner,
       drawsBadge = false,
       _isScopeOnly = true;

  /// `FeatureAccess.decide` for the feature this option belongs to.
  final FeatureDecision decision;

  /// The word of the plan that unlocks it, translated: "Pro" or "Hosted".
  /// Null where no plan does, and then no badge is drawn.
  final String? planWord;

  /// The word "locked", translated, for a screen reader.
  final String lockedWord;

  final Widget child;

  /// What the option is called. With it, a locked option is one stop for a
  /// screen reader: the name, [lockedWord], [planWord]. Without it the
  /// child keeps its own words.
  final String? name;

  /// What a double tap does on a locked option, for a screen reader.
  final String? hint;

  /// A tap on the option while it is locked: try it, or open the paywall.
  /// The caller picks. Null leaves the taps with the child.
  final VoidCallback? onLockedTap;

  /// Opens the paywall. Handed to the child through [FeatureLockScope].
  final VoidCallback? onUnlock;

  /// The corner the badge sits on.
  final AlignmentGeometry badgeAlignment;

  /// How far the badge hangs past the child's edge. Negative sets it in
  /// from the edge instead. With [FeatureLockSeat.above] it is sideways
  /// only.
  final double badgeOverhang;

  /// On the corner, or above the edge. See [FeatureLockSeat].
  final FeatureLockSeat badgeSeat;

  /// False for a child that places a [FeatureLockBadge] in its own layout,
  /// where its words can wrap before it. The lock still takes the tap and
  /// speaks for the option.
  final bool drawsBadge;

  /// How far a badge seated above the child reaches down over its edge.
  static const double badgeTuck = 5;

  /// The text size a badge seated above stops growing at, so the room
  /// over the child can be a fixed one.
  static const double badgeMaxTextScale = 1.3;

  /// The room a badge seated above needs over the child, at any text
  /// size.
  static const double badgeRoomAbove = 22;

  final bool _isScopeOnly;

  bool get isLocked => decision is FeatureLocked;

  @override
  Widget build(BuildContext context) {
    final locked = isLocked;
    final scope = FeatureLockScope(
      decision: decision,
      planWord: planWord,
      unlock: locked ? onUnlock : null,
      child: _isScopeOnly ? child : _wrapped(locked),
    );
    return scope;
  }

  /// The same tree whether locked or not, so the child keeps its state when
  /// the plan arrives and the badge goes.
  Widget _wrapped(bool locked) {
    final word = planWord;
    final takesTap = locked && onLockedTap != null;
    final spoken = locked && name != null;
    return Semantics(
      container: spoken,
      button: spoken ? true : null,
      label: spoken
          ? featureLockSpoken(
              name: name!,
              lockedWord: lockedWord,
              planWord: word,
            )
          : null,
      hint: spoken ? hint : null,
      onTap: spoken ? onLockedTap : null,
      excludeSemantics: spoken,
      child: GestureDetector(
        behavior: takesTap
            ? HitTestBehavior.opaque
            : HitTestBehavior.deferToChild,
        onTap: takesTap ? onLockedTap : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            IgnorePointer(ignoring: takesTap, child: child),
            if (locked && word != null && drawsBadge)
              if (badgeSeat == FeatureLockSeat.above)
                _BadgeAbove(overhang: badgeOverhang, word: word)
              else
                Positioned(
                  left: -badgeOverhang,
                  top: -badgeOverhang,
                  right: -badgeOverhang,
                  bottom: -badgeOverhang,
                  child: IgnorePointer(
                    child: Align(
                      alignment: badgeAlignment,
                      child: ProBadge(label: word, isLocked: true),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// The badge above the child's top end corner: its bottom edge sits
/// [FeatureLock.badgeTuck] under the child's top edge, whatever its own
/// height, so nothing of the child's content is under it.
class _BadgeAbove extends StatelessWidget {
  const _BadgeAbove({required this.overhang, required this.word});

  final double overhang;
  final String word;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return PositionedDirectional(
      start: -overhang,
      end: -overhang,
      top: FeatureLock.badgeTuck,
      child: IgnorePointer(
        child: FractionalTranslation(
          translation: const Offset(0, -1),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            heightFactor: 1,
            child: MediaQuery(
              data: media.copyWith(
                textScaler: media.textScaler.clamp(
                  maxScaleFactor: FeatureLock.badgeMaxTextScale,
                ),
              ),
              child: ProBadge(label: word, isLocked: true),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the nearest [FeatureLock] knows, for a child that draws the badge
/// or opens the paywall itself.
class FeatureLockScope extends InheritedWidget {
  const FeatureLockScope({
    required this.decision,
    required this.planWord,
    required this.unlock,
    required super.child,
    super.key,
  });

  final FeatureDecision decision;
  final String? planWord;

  /// Opens the paywall. Null when nothing is locked.
  final VoidCallback? unlock;

  bool get isLocked => decision is FeatureLocked;

  static FeatureLockScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FeatureLockScope>();

  @override
  bool updateShouldNotify(FeatureLockScope oldWidget) =>
      decision != oldWidget.decision ||
      planWord != oldWidget.planWord ||
      (unlock == null) != (oldWidget.unlock == null);
}

/// The plan badge of the nearest [FeatureLock], for a child that has a
/// place of its own for it: beside a title, under a name.
///
/// Locked, it is the pill with the lock glyph. Otherwise it draws nothing,
/// unless [staysWhenOpen] keeps the plain pill as a label for what the
/// plan includes.
class FeatureLockBadge extends StatelessWidget {
  const FeatureLockBadge({this.staysWhenOpen = false, super.key});

  final bool staysWhenOpen;

  @override
  Widget build(BuildContext context) {
    final scope = FeatureLockScope.maybeOf(context);
    final word = scope?.planWord;
    if (scope == null || word == null) return const SizedBox.shrink();
    if (scope.isLocked) return ProBadge(label: word, isLocked: true);
    return staysWhenOpen ? ProBadge(label: word) : const SizedBox.shrink();
  }
}
