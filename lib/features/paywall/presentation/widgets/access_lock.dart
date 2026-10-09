import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/lock_tap_rule.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// What a tap on a locked option is for. `lockTapFor` turns it into what
/// happens.
enum LockTap {
  /// Calls back, so the page can show the option working without saving
  /// it. With no [AccessLock.onTry], the tap is the person reaching for the
  /// option and the paywall opens.
  tryIt,

  /// The person acts to keep or use the option, so the paywall opens for
  /// the plan that unlocks it. The rule calls this `keep`.
  sell,

  /// The option leads to a page or a sheet of its own. The badge is drawn
  /// and the child keeps the tap and its own semantics. Nothing here opens
  /// a paywall: the page does, at the moment of use.
  open,
}

/// The word on the badge for [holding]: "Hosted" or "Pro".
String planWordFor(Holding holding) => switch (holding) {
  Holding.hosted => LocaleKeys.paywall_pro_badge.tr(),
  Holding.pro => LocaleKeys.pro_pack_badge.tr(),
};

/// Opens the paywall for [feature] from [source]. Does nothing unless the
/// feature is locked.
///
/// It waits for the plan to be read first. Before that the access layer
/// can say "locked" for something that is held, and a tap right after a
/// cold start must never show a paywall to someone who already pays.
///
/// For the one control on a page that sells a locked feature from outside
/// its [AccessLock], such as the bar under the Personalize preview.
Future<void> openPaywallForFeature(
  BuildContext context,
  AppFeature feature,
  LockSource source,
) async {
  final access = getIt<FeatureAccess>();
  await access.ready;
  if (!context.mounted) return;
  await openPaywallFor(context, access.decide(feature), source);
}

/// The plan word to put on an option that [feature] locks, or null when it
/// is not locked or the plan has not been read yet. For a sheet that lists
/// every option and badges the locked ones, so nothing is badged on a
/// guess.
String? lockedPlanWord(AppFeature feature) {
  final access = getIt<FeatureAccess>();
  if (!access.isPlanRead) return null;
  final decision = access.decide(feature);
  return decision is FeatureLocked ? planWordFor(decision.offer) : null;
}

/// What happens when the person picks an option that needs [feature] to
/// keep it: sheet rows, "set as default". Returns true when nothing is
/// locked and the caller goes ahead and saves it. When it is locked, opens
/// the paywall from [source] and returns false.
///
/// It waits for the plan to be read first, so a pick right after a cold
/// start never sells to someone who already pays and never saves for
/// someone who does not. What a pick does comes from `lockTapFor`.
Future<bool> keepOrOpenPaywall(
  BuildContext context,
  AppFeature feature,
  LockSource source,
) async {
  final access = getIt<FeatureAccess>();
  await access.ready;
  if (!context.mounted) return false;
  final decision = access.decide(feature);
  final answer = lockTapFor(
    decision: decision,
    isPlanRead: access.isPlanRead,
    hasTry: false,
    tap: LockTapKind.keep,
  );
  switch (answer) {
    case DoIt():
      return true;
    case OpenPaywall(:final offer):
      await openPaywallFor(context, FeatureDecision.locked(offer), source);
      return false;
    case OpenPage() || TryIt() || WaitForPlan() || Nothing():
      return false;
  }
}

/// The location [openPaywallForFeature] would open, or null when [feature]
/// is not locked. For a caller that closes itself first and is left with
/// a router and no context, such as a sheet. It waits for the plan to be
/// read, as [openPaywallForFeature] does.
Future<String?> paywallLocationForFeature(
  AppFeature feature,
  LockSource source,
) async {
  final access = getIt<FeatureAccess>();
  await access.ready;
  return paywallLocationFor(access.decide(feature), source);
}

/// [FeatureLock], fed from `FeatureAccess` for one [feature].
///
/// It reads the decision, redraws when `FeatureAccess.changes` names the
/// feature, picks the plan word, and opens the paywall through the one
/// door with [source]. What a tap does comes from `lockTapFor`. A screen
/// wraps an option in this and decides nothing about plans itself.
///
/// The badge is drawn only once the plan has been read
/// (`FeatureAccess.isPlanRead`), so a phone that holds the plan never
/// flashes it.
///
/// [AccessLock.inline] is for a surface with a place of its own for the
/// badge and a button of its own for the paywall: it draws nothing over
/// the child and takes no tap. The child places a [FeatureLockBadge] and
/// calls `FeatureLockScope.maybeOf(context)?.unlock`.
class AccessLock extends StatefulWidget {
  const AccessLock({
    required this.feature,
    required this.source,
    required this.child,
    this.name,
    this.tap = LockTap.sell,
    this.onTry,
    this.onLockedTap,
    this.badgeAlignment = AlignmentDirectional.topEnd,
    this.badgeOverhang = 6,
    this.badgeSeat = FeatureLockSeat.corner,
    this.drawsBadge = true,
    this.decide,
    super.key,
  }) : _isInline = false;

  const AccessLock.inline({
    required this.feature,
    required this.source,
    required this.child,
    this.decide,
    super.key,
  }) : name = null,
       tap = LockTap.sell,
       onTry = null,
       onLockedTap = null,
       badgeAlignment = AlignmentDirectional.topEnd,
       badgeOverhang = 0,
       badgeSeat = FeatureLockSeat.corner,
       drawsBadge = false,
       _isInline = true;

  final AppFeature feature;

  /// Where the person met the lock, for the paywall that opens.
  final LockSource source;

  final Widget child;

  /// What the option is called, for a screen reader. See
  /// [FeatureLock.name].
  final String? name;

  final LockTap tap;

  /// Called for a tap on the locked option when [tap] is [LockTap.tryIt].
  final VoidCallback? onTry;

  /// Takes over a tap on the locked option, in place of [tap]. For a
  /// screen with a gate of its own in front of the paywall.
  final VoidCallback? onLockedTap;

  final AlignmentGeometry badgeAlignment;

  /// How far the badge hangs past the child's edge. Negative sets it in.
  final double badgeOverhang;

  /// See [FeatureLock.badgeSeat].
  final FeatureLockSeat badgeSeat;

  /// See [FeatureLock.drawsBadge].
  final bool drawsBadge;

  /// The decision to draw, for a surface that is locked by something
  /// besides the holdings, such as a row that stays locked while a
  /// purchase is being confirmed. Left out, it is
  /// `FeatureAccess.decide(feature)`.
  final FeatureDecision Function(FeatureAccess access)? decide;

  final bool _isInline;

  @override
  State<AccessLock> createState() => _AccessLockState();
}

class _AccessLockState extends State<AccessLock> {
  late final FeatureAccess _access = getIt<FeatureAccess>();
  StreamSubscription<AppFeature>? _changes;

  @override
  void initState() {
    super.initState();
    // The stream only carries changes, so the value is read each build.
    _changes = _access.changes.listen((feature) {
      if (feature == widget.feature && mounted) setState(() {});
    });
    _access.planRead.addListener(_planWasRead);
  }

  @override
  void dispose() {
    _access.planRead.removeListener(_planWasRead);
    unawaited(_changes?.cancel());
    super.dispose();
  }

  void _planWasRead() {
    if (mounted) setState(() {});
  }

  FeatureDecision _decide() =>
      widget.decide?.call(_access) ?? _access.decide(widget.feature);

  LockTapAnswer _ask(LockTapKind kind) => lockTapFor(
    decision: _decide(),
    isPlanRead: _access.isPlanRead,
    hasTry: widget.onTry != null,
    tap: kind,
  );

  /// Does what the rule says a tap of [kind] does. Anything that could
  /// sell, try or save waits for the plan to be read first, so a paywall or
  /// a try is never shown to someone who already pays.
  Future<void> _act(LockTapKind kind) async {
    var answer = _ask(kind);
    if (answer is WaitForPlan) {
      await _access.ready;
      if (!mounted) return;
      // The lock on screen was early: draw what is true.
      setState(() {});
      answer = _ask(kind);
    }
    switch (answer) {
      case OpenPaywall(:final offer):
        await openPaywallFor(
          context,
          FeatureDecision.locked(offer),
          widget.source,
        );
      case TryIt():
        widget.onTry?.call();
      case OpenPage() || DoIt() || WaitForPlan() || Nothing():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final decision = _decide();
    // The plan that would unlock it here, held or not, so an open option
    // can still be labelled with it. Null where no plan does: a feature
    // with no row, one a server of the user's own opens, and one that is
    // not offered there. No badge is drawn for any of them.
    final nothing = _access.decideHoldingNothing(widget.feature);
    final holding = switch (decision) {
      FeatureLocked(:final offer) => offer,
      _ => nothing is FeatureLocked ? nothing.offer : null,
    };
    // Nothing is badged before the plan is read: what is drawn then can
    // be from before a held plan was known.
    final isPlanRead = _access.isPlanRead;
    final planWord = holding == null || !isPlanRead
        ? null
        : planWordFor(holding);
    void unlock() => unawaited(_act(LockTapKind.keep));

    if (widget._isInline) {
      return FeatureLock.scope(
        decision: decision,
        planWord: planWord,
        onUnlock: unlock,
        child: widget.child,
      );
    }
    final isOpen = widget.tap == LockTap.open;
    final tries = widget.tap == LockTap.tryIt;
    return FeatureLock(
      decision: decision,
      planWord: planWord,
      lockedWord: LocaleKeys.feature_lock_locked.tr(),
      // The child of an option that opens a page keeps its own words.
      name: isOpen ? null : widget.name,
      hint: isOpen
          ? null
          : tries
          ? LocaleKeys.feature_lock_try_hint.tr()
          : planWord == null
          ? null
          : LocaleKeys.feature_lock_sell_hint.tr(namedArgs: {'plan': planWord}),
      onLockedTap: isOpen
          ? widget.onLockedTap
          : widget.onLockedTap ??
                (tries ? () => unawaited(_act(LockTapKind.tryIt)) : unlock),
      onUnlock: unlock,
      badgeAlignment: widget.badgeAlignment,
      badgeOverhang: widget.badgeOverhang,
      badgeSeat: widget.badgeSeat,
      drawsBadge: widget.drawsBadge && isPlanRead,
      child: widget.child,
    );
  }
}
