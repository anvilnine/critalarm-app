import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/core/paywall/paywall_outro.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/paywall/paywall_thanks.dart';
import 'package:critalarm/core/push/push_deep_link.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/history_own.dart';
import 'package:critalarm/features/paywall/domain/leaving_numbers.dart';
import 'package:critalarm/features/paywall/domain/leaving_seen.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead_facts.dart';
import 'package:critalarm/features/paywall/domain/paywall_leaving.dart';
import 'package:critalarm/features/paywall/domain/paywall_routing.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_outro_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks_registry.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The one way into either paywall.
///
/// It reads what [paywallOpeningFor] needs (what Developer options set,
/// whether the false alarm intro was shown) and answers with the location
/// of a layout, with its intro, its thanks and its outro. There is always
/// an answer: anything that goes wrong while it reads opens the layout of
/// the plan place for that product.
class PaywallDoor {
  PaywallDoor({
    required this._developer,
    required this._hasSeenFalseAlarm,
    required this._markFalseAlarmSeen,
    this._developerIntro = _noDeveloperIntro,
    this._isIntroBuilt = paywallIntroIsBuilt,
    this._developerThanks = _noDeveloperThanks,
    this._isThanksBuilt = paywallThanksIsBuilt,
    this._developerOutro = _noDeveloperOutro,
    this._isOutroBuilt = paywallOutroIsBuilt,
    this._widgetsDecision = _widgetsLockedForPro,
    this._listedBenefits = _builtBenefitIds,
    this._readHistoryOwn = _noHistoryOwn,
    this._readLeavingFacts = _noLeavingFacts,
    this._leavingShownFor = _noLeavingShown,
    this._markLeavingShown = _noLeavingMark,
    this._leavingReadTimeout = const Duration(seconds: 3),
  });

  /// The prefs key that says the false alarm intro was shown on this
  /// install. Set once, when a paywall opens on it.
  static const String falseAlarmShownKey = 'paywall.false_alarm_shown';

  static PaywallIntroId? _noDeveloperIntro(PaywallProduct product) => null;
  static PaywallThanksId? _noDeveloperThanks(PaywallProduct product) => null;
  static PaywallOutroId? _noDeveloperOutro(PaywallProduct product) => null;
  static Set<PaywallBenefitId> _builtBenefitIds(PaywallProduct product) => {
    for (final benefit in paywallBenefitsFor(product)) benefit.id,
  };

  static Future<HistoryOwn?> _noHistoryOwn() async => null;
  static Future<LeavingFacts?> _noLeavingFacts() async => null;
  static String? _noLeavingShown() => null;
  static Future<void> _noLeavingMark(String endsOn) async {}

  /// The prefs key that holds the end date the sad opening was last shown
  /// for, as `yyyy-MM-dd`.
  static const String leavingShownKey = 'paywall.leaving_shown_for';

  static FeatureDecision _widgetsLockedForPro() =>
      const FeatureDecision.locked(Holding.pro);

  final PaywallLayoutSetting? Function(PaywallProduct product) _developer;
  final PaywallIntroId? Function(PaywallProduct product) _developerIntro;
  final bool Function() _hasSeenFalseAlarm;
  final Future<void> Function() _markFalseAlarmSeen;
  final bool Function(PaywallIntroId intro) _isIntroBuilt;
  final PaywallThanksId? Function(PaywallProduct product) _developerThanks;
  final bool Function(PaywallThanksId thanks) _isThanksBuilt;
  final PaywallOutroId? Function(PaywallProduct product) _developerOutro;
  final bool Function(PaywallOutroId outro) _isOutroBuilt;

  /// `FeatureAccess.decide` for the widgets feature. A tap on a locked
  /// widget arrives as a link, and this is what picks its paywall.
  final FeatureDecision Function() _widgetsDecision;

  /// The benefit ids this build lists for a product. A lead outside this
  /// set is dropped by [paywallOpeningFor].
  final Set<PaywallBenefitId> Function(PaywallProduct product) _listedBenefits;

  /// The person's own history rows, read from the phone. Null when the
  /// phone holds nothing older than the Free window.
  final Future<HistoryOwn?> Function() _readHistoryOwn;

  /// The person's numbers for the leaving paywall, counted on the phone.
  /// Null when they cannot be counted.
  final Future<LeavingFacts?> Function() _readLeavingFacts;

  /// The end date the sad opening was last shown for, or null.
  final String? Function() _leavingShownFor;

  /// Writes the end date the sad opening is now being shown for.
  final Future<void> Function(String endsOn) _markLeavingShown;

  /// How long the door waits for the phone to count. A count that takes
  /// longer opens the paywall as if it had found nothing.
  final Duration _leavingReadTimeout;

  /// The person's own history rows, or null when the phone holds nothing
  /// older than the Free window or the read fails. Never throws.
  Future<HistoryOwn?> readHistoryOwn() async {
    try {
      return await _readHistoryOwn();
    } on Object catch (_) {
      return null;
    }
  }

  /// What opens for [product] from [place]. A paywall that opens on the
  /// false alarm intro is its one showing, so this writes that down. Never
  /// throws: a read that fails opens [planOpeningFor].
  PaywallOpening openingFor(
    PaywallProduct product,
    PaywallPlace place, {
    LeavingChoice? leaving,
  }) {
    try {
      // A false alarm this build cannot draw would open with no intro and
      // still use up its one showing.
      final canDrawFalseAlarm = _isIntroBuilt(PaywallIntroId.falseAlarm);
      final opening = paywallOpeningFor(
        product: product,
        place: place,
        listedBenefits: _listedBenefits(product),
        developer: _developer(product),
        developerIntro: _developerIntro(product),
        hasSeenFalseAlarm: !canDrawFalseAlarm || _hasSeenFalseAlarm(),
        developerThanks: _developerThanks(product),
        developerOutro: _developerOutro(product),
        leaving: leaving,
      );
      if (opening.intro == PaywallIntroId.falseAlarm) {
        _markFalseAlarmSeen().ignore();
      }
      return _drawable(opening);
    } on Object catch (_) {
      return planOpeningFor(product);
    }
  }

  /// [opening] with every step this build cannot draw taken out. An intro
  /// with no animation is no intro, and the same goes for a thanks. An
  /// outro needs a thanks to hand over to.
  PaywallOpening _drawable(PaywallOpening opening) {
    final thanks = _isThanksBuilt(opening.thanks)
        ? opening.thanks
        : PaywallThanksId.none;
    return PaywallOpening(
      opening.layout,
      intro: _isIntroBuilt(opening.intro) ? opening.intro : PaywallIntroId.none,
      thanks: thanks,
      outro: thanks != PaywallThanksId.none && _isOutroBuilt(opening.outro)
          ? opening.outro
          : PaywallOutroId.none,
      lead: opening.lead,
      headline: opening.headline,
    );
  }

  /// What opens when the door cannot read what it needs: the layout of the
  /// plan place for [product], with the coded thanks and outro and nothing
  /// from Developer options. Never throws.
  PaywallOpening planOpeningFor(PaywallProduct product) {
    try {
      return _drawable(_planOpening(product));
    } on Object catch (_) {
      return PaywallOpening(paywallRowFor(PaywallPlace.plan).layout);
    }
  }

  /// The location that opens Hosted for [source]. [own] is the person's
  /// own history rows: the location carries them only when the place leads
  /// with history. [facts] is the person's own critical topic count and
  /// the topic they were making: the location carries them only when the
  /// place leads with topics.
  String hostedLocation(
    PaywallSource source, {
    HistoryOwn? own,
    PaywallLeadFacts? facts,
  }) {
    final opening = openingFor(PaywallProduct.hosted, paywallPlaceOf(source));
    final location = paywallLayoutLocation(
      opening.layout,
      PaywallProduct.hosted,
      intro: opening.intro,
      thanks: opening.thanks,
      outro: opening.outro,
      source: source,
      lead: opening.lead,
      headline: opening.headline,
      own: opening.lead == PaywallBenefitId.history ? own : null,
    );
    return opening.lead == PaywallBenefitId.topics && facts != null
        ? _withFacts(location, facts)
        : location;
  }

  /// [location] with the entries of [facts] added after its own.
  static String _withFacts(String location, PaywallLeadFacts facts) {
    final entries = facts.toQuery();
    if (entries.isEmpty) return location;
    final uri = Uri.parse(location);
    return uri
        .replace(queryParameters: {...uri.queryParameters, ...entries})
        .toString();
  }

  /// The location that opens Hosted for a cancelled plan that ends on
  /// [endsAt]. It counts the person's numbers first, so it is asynchronous.
  ///
  /// With a Receipt or Wipe opening it carries the end date, whether the
  /// sad opening was shown for that date already (`rest=1`), and the
  /// numbers. The numbers are the person's own: they ride in this location
  /// to the screen that draws them and nowhere else.
  ///
  /// Anything that goes wrong opens the paywall anyway. A count that fails,
  /// takes too long or finds nothing is Wipe with no numbers; a failure
  /// anywhere else opens the plan layout for the same source. Never throws.
  Future<String> leavingLocation(DateTime endsAt) async {
    try {
      final endsOn = DateTime(endsAt.year, endsAt.month, endsAt.day);
      final facts = await _countLeavingFacts();
      final slip = facts == null ? null : leavingSlipFor(facts);
      final opening = openingFor(
        PaywallProduct.hosted,
        PaywallPlace.planEnding,
        leaving: LeavingChoice(
          showsReceipt: slip?.showsReceipt ?? false,
          historyDaysHeld: facts?.historyDaysHeld,
        ),
      );
      final atRest = _leavingWasShown(endsOn);
      if (!atRest) _rememberLeavingShown(endsOn);
      // Only the two layouts that draw the numbers get them.
      final drawsNumbers =
          opening.layout == PaywallLayoutId.receipt ||
          opening.layout == PaywallLayoutId.wipe;
      final own = opening.lead == PaywallBenefitId.history
          ? await _guarded(_readHistoryOwn)
          : null;
      return paywallLayoutLocation(
        opening.layout,
        PaywallProduct.hosted,
        intro: opening.intro,
        thanks: opening.thanks,
        outro: opening.outro,
        source: PaywallSource.planSheetEnding,
        lead: opening.lead,
        headline: opening.headline,
        own: own,
        leaving: PaywallLeaving(
          endsOn: endsOn,
          atRest: atRest,
          facts: drawsNumbers ? facts : null,
        ),
      );
    } on Object catch (_) {
      return planPaywallLocation(
        PaywallProduct.hosted,
        sourceWire: PaywallSource.planSheetEnding.wire,
      );
    }
  }

  /// [read], or null when it throws or takes longer than the wait.
  Future<T?> _guarded<T>(Future<T?> Function() read) async {
    try {
      return await read().timeout(_leavingReadTimeout);
    } on Object catch (_) {
      return null;
    }
  }

  Future<LeavingFacts?> _countLeavingFacts() => _guarded(_readLeavingFacts);

  bool _leavingWasShown(DateTime endsOn) {
    try {
      return leavingWasShown(_leavingShownFor(), endsOn);
    } on Object catch (_) {
      return false;
    }
  }

  /// Writes down that the sad opening is being shown for [endsOn]. A write
  /// that fails changes nothing for this open.
  void _rememberLeavingShown(DateTime endsOn) {
    try {
      unawaited(
        _markLeavingShown(leavingSeenKeyFor(endsOn)).catchError((_) {}),
      );
    } on Object catch (_) {
      // The next open shows the sad opening again. Nothing else is lost.
    }
  }

  /// [location] as the app opens it. A `/paywall?source=...` path is the
  /// layout for that source, and any other location comes back unchanged.
  /// For a path built where no door is at hand: a reminder, a widget tap, a
  /// search result. It never answers with a `/paywall` path.
  String resolve(String location) {
    final uri = Uri.tryParse(location);
    if (uri == null || uri.path != paywallPath) return location;
    final source = PaywallSource.parse(uri.queryParameters['source']);
    if (source == PaywallSource.widgetLocked) return _widgetTapLocation();
    return hostedLocation(source);
  }

  /// Where a tap on a locked widget goes, by the widgets decision: the
  /// paywall of the product it offers. A widget that is not locked any
  /// more (Pro was bought since it was drawn, or the plan cannot be read)
  /// sells nothing, so the tap opens Home.
  String _widgetTapLocation() {
    final FeatureDecision decision;
    try {
      decision = _widgetsDecision();
    } on Object catch (_) {
      return PushDeepLink.homeLocation;
    }
    if (decision is! FeatureLocked) return PushDeepLink.homeLocation;
    return switch (decision.offer) {
      Holding.hosted => hostedLocation(LockSource.widgetLocked.hosted),
      Holding.pro => proLayoutLocation(LockSource.widgetLocked.pro),
    };
  }

  /// The location of the layout that opens Pro for [source].
  String proLayoutLocation(ProPackSheetSource source) {
    final opening = openingFor(
      PaywallProduct.pro,
      paywallPlaceOfPro(source),
    );
    return paywallLayoutLocation(
      opening.layout,
      PaywallProduct.pro,
      intro: opening.intro,
      thanks: opening.thanks,
      outro: opening.outro,
      sourceWire: source.wire,
      lead: opening.lead,
      headline: opening.headline,
    );
  }
}

/// The plan place for [product] with the coded thanks and outro, before
/// anything is checked against what this build can draw.
PaywallOpening _planOpening(PaywallProduct product) => paywallOpeningFor(
  product: product,
  place: PaywallPlace.plan,
  // The plan place plays no intro and names no lead.
  hasSeenFalseAlarm: true,
  listedBenefits: const {},
);

/// The location of the layout the plan place opens for [product]. What
/// opens when no door is registered or the door fails. [sourceWire] is the
/// `source` the location keeps for analytics. Never throws.
String planPaywallLocation(PaywallProduct product, {String? sourceWire}) {
  PaywallOpening opening;
  try {
    final planned = _planOpening(product);
    final thanks = paywallThanksIsBuilt(planned.thanks)
        ? planned.thanks
        : PaywallThanksId.none;
    opening = PaywallOpening(
      planned.layout,
      thanks: thanks,
      outro:
          thanks != PaywallThanksId.none && paywallOutroIsBuilt(planned.outro)
          ? planned.outro
          : PaywallOutroId.none,
    );
  } on Object catch (_) {
    opening = PaywallOpening(paywallRowFor(PaywallPlace.plan).layout);
  }
  return paywallLayoutLocation(
    opening.layout,
    product,
    thanks: opening.thanks,
    outro: opening.outro,
    sourceWire: sourceWire ?? directPaywallSource,
  );
}

PaywallDoor? get _door =>
    getIt.isRegistered<PaywallDoor>() ? getIt<PaywallDoor>() : null;

/// The location that opens the Hosted paywall for [source]. Every place
/// that opens it asks here.
String hostedPaywallLocation(
  PaywallSource source, {
  PaywallLeadFacts? facts,
}) =>
    _door?.hostedLocation(source, facts: facts) ??
    planPaywallLocation(PaywallProduct.hosted, sourceWire: source.wire);

/// The location that opens the leaving paywall: see
/// [PaywallDoor.leavingLocation]. Never throws.
Future<String> leavingPaywallLocation(DateTime endsAt) async =>
    await _door?.leavingLocation(endsAt) ??
    planPaywallLocation(
      PaywallProduct.hosted,
      sourceWire: PaywallSource.planSheetEnding.wire,
    );

/// [hostedPaywallLocation] for [source], with the person's own history rows
/// when the place leads with history. For a caller that can wait a moment.
Future<String> hostedPaywallLocationWithOwn(
  PaywallSource source, {
  PaywallLeadFacts? facts,
}) async {
  final door = _door;
  if (door == null) {
    return planPaywallLocation(PaywallProduct.hosted, sourceWire: source.wire);
  }
  final leadsWithHistory =
      paywallRowFor(paywallPlaceOf(source)).lead == PaywallBenefitId.history;
  final own = leadsWithHistory ? await door.readHistoryOwn() : null;
  return door.hostedLocation(source, own: own, facts: facts);
}

/// [location] as the app should open it: see [PaywallDoor.resolve]. With
/// no door registered a `/paywall` path opens the plan layout for Hosted.
/// It never answers with a `/paywall` path.
String resolvePaywallLocation(String location) {
  final door = _door;
  if (door != null) return door.resolve(location);
  final uri = Uri.tryParse(location);
  if (uri == null || uri.path != paywallPath) return location;
  return planPaywallLocation(
    PaywallProduct.hosted,
    sourceWire: PaywallSource.parse(uri.queryParameters['source']).wire,
  );
}

/// [resolvePaywallLocation], for a location that may be a tap on a locked
/// widget. It waits for the plan to be read first, so a tap right after a
/// cold start never sells Pro to someone who holds it.
Future<String> resolvePaywallLocationWhenReady(String location) async {
  if (Uri.tryParse(location)?.path == paywallPath &&
      getIt.isRegistered<FeatureAccess>()) {
    await getIt<FeatureAccess>().ready.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
  }
  return resolvePaywallLocation(location);
}

/// The location that opens the Pro paywall for [source].
String proPaywallLocation(ProPackSheetSource source) =>
    _door?.proLayoutLocation(source) ??
    planPaywallLocation(PaywallProduct.pro, sourceWire: source.wire);

/// Opens the Pro paywall for [source]. Every place that opens it asks here.
Future<void> openProPaywall(BuildContext context, ProPackSheetSource source) =>
    context.push<void>(proPaywallLocation(source));

/// The one way from a locked feature to a paywall.
///
/// [decision] is `FeatureAccess.decide` for the feature the person reached
/// for, and [source] is where they met the lock. The caller never names a
/// product: a decision that offers Hosted opens the Hosted paywall, one
/// that offers Pro opens the Pro paywall. A decision that is open,
/// confirming, unread or not offered opens nothing, because there is
/// nothing to sell.
Future<void> openPaywallFor(
  BuildContext context,
  FeatureDecision decision,
  LockSource source, {
  PaywallLeadFacts? facts,
}) async {
  final Holding offer;
  switch (decision) {
    case FeatureLocked():
      offer = decision.offer;
    case FeatureOpen() ||
        FeatureConfirming() ||
        FeatureUnread() ||
        FeatureNotOffered():
      return;
  }
  switch (offer) {
    case Holding.hosted:
      final location = await hostedPaywallLocationWithOwn(
        source.hosted,
        facts: facts,
      );
      if (!context.mounted) return;
      await context.push<void>(location);
    case Holding.pro:
      await openProPaywall(context, source.pro);
  }
}

/// The location [openPaywallFor] opens, or null when [decision] locks
/// nothing. For a caller that holds a router and no context, such as a
/// sheet that closes itself before the paywall opens.
String? paywallLocationFor(
  FeatureDecision decision,
  LockSource source, {
  PaywallLeadFacts? facts,
}) {
  if (decision is! FeatureLocked) return null;
  return switch (decision.offer) {
    Holding.hosted => hostedPaywallLocation(source.hosted, facts: facts),
    Holding.pro => proPaywallLocation(source.pro),
  };
}
