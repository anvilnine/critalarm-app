import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// What a tap on a locked option does.
enum LockTap {
  /// Calls back, so the page can show the option working without saving
  /// it.
  tryIt,

  /// Opens the paywall for the plan that unlocks it.
  sell,
}

/// The word on the badge for [holding]: "Hosted" or "Pro".
String planWordFor(Holding holding) => switch (holding) {
  Holding.hosted => LocaleKeys.paywall_pro_badge.tr(),
  Holding.pro => LocaleKeys.pro_pack_badge.tr(),
};

/// Opens the paywall for [feature] as it stands now, from [source]. Does
/// nothing unless the feature is locked.
///
/// For the one control on a page that sells a locked feature from outside
/// its [AccessLock], such as the bar under the Personalize preview.
Future<void> openPaywallForFeature(
  BuildContext context,
  AppFeature feature,
  LockSource source, {
  bool isSelfHosted = false,
}) => openPaywallFor(
  context,
  getIt<FeatureAccess>().decide(feature),
  source,
  isSelfHosted: isSelfHosted,
);

/// The location [openPaywallForFeature] would open, or null when [feature]
/// is not locked. For a caller that closes itself first and is left with
/// a router and no context, such as a sheet.
String? paywallLocationForFeature(
  AppFeature feature,
  LockSource source, {
  bool isSelfHosted = false,
}) => paywallLocationFor(
  getIt<FeatureAccess>().decide(feature),
  source,
  isSelfHosted: isSelfHosted,
);

/// [FeatureLock], fed from `FeatureAccess` for one [feature].
///
/// It reads the decision, redraws when `FeatureAccess.changes` names the
/// feature, picks the plan word, and opens the paywall through the one
/// door with [source]. A screen wraps an option in this and decides
/// nothing about plans itself.
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
    this.isSelfHosted = false,
    this.badgeAlignment = AlignmentDirectional.topEnd,
    this.badgeOverhang = 6,
    this.decide,
    super.key,
  }) : _isInline = false;

  const AccessLock.inline({
    required this.feature,
    required this.source,
    required this.child,
    this.isSelfHosted = false,
    this.decide,
    super.key,
  }) : name = null,
       tap = LockTap.sell,
       onTry = null,
       badgeAlignment = AlignmentDirectional.topEnd,
       badgeOverhang = 0,
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

  /// The opener's own knowledge of the phone. Only the Pro sheet has a
  /// line for it.
  final bool isSelfHosted;

  final AlignmentGeometry badgeAlignment;

  /// How far the badge hangs past the child's edge. Negative sets it in.
  final double badgeOverhang;

  /// The decision to draw, for a surface that is locked by something
  /// besides the holdings, such as a row the relay refused. Left out, it
  /// is `FeatureAccess.decide(feature)`.
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
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decision =
        widget.decide?.call(_access) ?? _access.decide(widget.feature);
    // The plan that would unlock it here, held or not, so an open option
    // can still be labelled with it. Null where no plan does.
    final nothing = _access.decideHoldingNothing(widget.feature);
    final holding = switch (decision) {
      FeatureLocked(:final offer) => offer,
      _ => nothing is FeatureLocked ? nothing.offer : null,
    };
    final planWord = holding == null ? null : planWordFor(holding);
    void unlock() => unawaited(
      openPaywallFor(
        context,
        decision,
        widget.source,
        isSelfHosted: widget.isSelfHosted,
      ),
    );

    if (widget._isInline) {
      return FeatureLock.scope(
        decision: decision,
        planWord: planWord,
        onUnlock: unlock,
        child: widget.child,
      );
    }
    final tries = widget.tap == LockTap.tryIt;
    return FeatureLock(
      decision: decision,
      planWord: planWord,
      lockedWord: LocaleKeys.feature_lock_locked.tr(),
      name: widget.name,
      hint: tries
          ? LocaleKeys.feature_lock_try_hint.tr()
          : LocaleKeys.feature_lock_sell_hint.tr(
              namedArgs: {'plan': planWord ?? ''},
            ),
      onLockedTap: tries ? widget.onTry : unlock,
      onUnlock: unlock,
      badgeAlignment: widget.badgeAlignment,
      badgeOverhang: widget.badgeOverhang,
      child: widget.child,
    );
  }
}
