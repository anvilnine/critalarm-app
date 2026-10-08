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

/// The one way the app draws something a plan would unlock.
///
/// It wraps any option and draws it from a [FeatureDecision]:
///
/// - Open, confirming or unread: the child, untouched. A purchase being
///   confirmed and a plan that could not be read both count as usable, so
///   neither draws a lock.
/// - Locked: the child at full colour with the plan badge on its corner, a
///   lock glyph and [planWord]. Nothing is dimmed or blurred. A tap goes to
///   [onLockedTap] and never to the child.
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
  /// from the edge instead.
  final double badgeOverhang;

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
            if (locked && word != null)
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
