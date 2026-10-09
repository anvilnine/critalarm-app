import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/paywall/paywall_thanks.dart';
import 'package:critalarm/core/push/push_deep_link.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/domain/paywall_routing.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks_registry.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:critalarm/features/pro_pack/presentation/pro_pack_sheet_page.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The one way into either paywall.
///
/// It reads what [paywallOpeningFor] needs (the remote values, what
/// Developer options set, whether the false alarm intro was shown) and
/// answers with a location: the shipped route, exactly as before, or a
/// layout's, with its intro and its thanks. Anything that goes wrong
/// while it reads answers with the shipped route.
class PaywallDoor {
  PaywallDoor({
    required this._remoteValue,
    required this._developer,
    required this._hasSeenFalseAlarm,
    required this._markFalseAlarmSeen,
    this._remoteIntroValue = _noIntroValue,
    this._developerIntro = _noDeveloperIntro,
    this._isIntroBuilt = paywallIntroIsBuilt,
    this._remoteThanksValue = _noThanksValue,
    this._developerThanks = _noDeveloperThanks,
    this._isThanksBuilt = paywallThanksIsBuilt,
    this._widgetsDecision = _widgetsLockedForPro,
  });

  /// The prefs key that says the false alarm intro was shown on this
  /// install. Set once, when a paywall opens on it.
  static const String falseAlarmShownKey = 'paywall.false_alarm_shown';

  static String _noIntroValue(PaywallProduct product) => '';
  static PaywallIntroId? _noDeveloperIntro(PaywallProduct product) => null;
  static String _noThanksValue(PaywallProduct product) => '';
  static PaywallThanksId? _noDeveloperThanks(PaywallProduct product) => null;
  static FeatureDecision _widgetsLockedForPro() =>
      const FeatureDecision.locked(Holding.pro);

  final String Function(PaywallProduct product) _remoteValue;
  final PaywallLayoutSetting? Function(PaywallProduct product) _developer;
  final String Function(PaywallProduct product) _remoteIntroValue;
  final PaywallIntroId? Function(PaywallProduct product) _developerIntro;
  final bool Function() _hasSeenFalseAlarm;
  final Future<void> Function() _markFalseAlarmSeen;
  final bool Function(PaywallIntroId intro) _isIntroBuilt;
  final String Function(PaywallProduct product) _remoteThanksValue;
  final PaywallThanksId? Function(PaywallProduct product) _developerThanks;
  final bool Function(PaywallThanksId thanks) _isThanksBuilt;

  /// `FeatureAccess.decide` for the widgets feature. A tap on a locked
  /// widget arrives as a link, and this is what picks its paywall.
  final FeatureDecision Function() _widgetsDecision;

  PaywallLayoutSetting _setting(PaywallProduct product) =>
      _developer(product) ?? PaywallLayoutSetting.parse(_remoteValue(product));

  /// Whether [product] is set to open layouts at all. False at the
  /// defaults: the layout route then has nothing to draw for a user.
  bool opensLayouts(PaywallProduct product) {
    try {
      return !_setting(product).isShipped;
    } on Object catch (_) {
      return false;
    }
  }

  /// What opens for [product] from [entry], or null for the shipped
  /// surface. A paywall that opens on the false alarm intro is its one
  /// showing, so this writes that down.
  PaywallOpening? openingFor(PaywallProduct product, PaywallEntry entry) {
    try {
      final remoteValue = _remoteValue(product);
      final developer = _developer(product);
      // A false alarm this build cannot draw would open with no intro and
      // still use up its one showing.
      final canDrawFalseAlarm = _isIntroBuilt(PaywallIntroId.falseAlarm);
      final opening = paywallOpeningFor(
        product: product,
        entry: entry,
        remote: PaywallLayoutSetting.parse(remoteValue),
        developer: developer,
        remoteIntro: PaywallIntroId.parse(_remoteIntroValue(product)),
        developerIntro: _developerIntro(product),
        legacyIntro: developer == null
            ? paywallIntroInLayoutValue(remoteValue)
            : null,
        hasSeenFalseAlarm: !canDrawFalseAlarm || _hasSeenFalseAlarm(),
        remoteThanks: PaywallThanksId.parse(_remoteThanksValue(product)),
        developerThanks: _developerThanks(product),
      );
      if (opening == null) return null;
      if (opening.intro == PaywallIntroId.falseAlarm) {
        _markFalseAlarmSeen().ignore();
      }
      // An intro this build has no animation for is no intro, and the
      // same goes for a thanks.
      return PaywallOpening(
        opening.layout,
        intro: _isIntroBuilt(opening.intro)
            ? opening.intro
            : PaywallIntroId.none,
        thanks: _isThanksBuilt(opening.thanks)
            ? opening.thanks
            : PaywallThanksId.none,
      );
    } on Object catch (_) {
      return null;
    }
  }

  /// The location that opens Hosted for [source].
  String hostedLocation(PaywallSource source) {
    final opening = openingFor(PaywallProduct.hosted, paywallEntryOf(source));
    return opening == null
        ? paywallLocation(source)
        : paywallLayoutLocation(
            opening.layout,
            PaywallProduct.hosted,
            intro: opening.intro,
            thanks: opening.thanks,
            source: source,
          );
  }

  /// [location], unless it is the shipped Hosted paywall and that is set
  /// to open a layout. For a path built where no door is at hand: a
  /// reminder, a widget tap, a search result.
  String resolve(String location) {
    final uri = Uri.tryParse(location);
    if (uri == null || uri.path != paywallPath) return location;
    final source = PaywallSource.parse(uri.queryParameters['source']);
    if (source == PaywallSource.widgetLocked) return _widgetTapLocation();
    final opening = openingFor(PaywallProduct.hosted, paywallEntryOf(source));
    return opening == null
        ? location
        : paywallLayoutLocation(
            opening.layout,
            PaywallProduct.hosted,
            intro: opening.intro,
            thanks: opening.thanks,
            source: source,
          );
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
      Holding.pro =>
        proLayoutLocation(LockSource.widgetLocked.pro) ??
            Uri(
              path: proPackSheetPath,
              queryParameters: {'source': LockSource.widgetLocked.pro.wire},
            ).toString(),
    };
  }

  /// The location of the layout that opens Pro for [source], or null for
  /// the Pro sheet.
  String? proLayoutLocation(ProPackSheetSource source) {
    final opening = openingFor(
      PaywallProduct.pro,
      paywallEntryOfProSheet(source),
    );
    return opening == null
        ? null
        : paywallLayoutLocation(
            opening.layout,
            PaywallProduct.pro,
            intro: opening.intro,
            thanks: opening.thanks,
            sourceWire: source.wire,
          );
  }

  /// Where a layout location goes when its product is not set to open
  /// layouts: the shipped surface for that product, with the same source.
  /// Null when the layout may draw.
  String? shippedInsteadOf(Uri layoutLocation) {
    final query = layoutLocation.queryParameters;
    final product = PaywallProduct.parse(query['product']);
    if (opensLayouts(product)) return null;
    return switch (product) {
      PaywallProduct.hosted => paywallLocation(
        PaywallSource.parse(query['source']),
      ),
      PaywallProduct.pro => Uri(
        path: proPackSheetPath,
        queryParameters: {
          'source': ProPackSheetSource.parse(query['source']).wire,
        },
      ).toString(),
    };
  }
}

PaywallDoor? get _door =>
    getIt.isRegistered<PaywallDoor>() ? getIt<PaywallDoor>() : null;

/// The location that opens the Hosted paywall for [source]. Every place
/// that opens it asks here.
String hostedPaywallLocation(PaywallSource source) =>
    _door?.hostedLocation(source) ?? paywallLocation(source);

/// [location] as the app should open it: see [PaywallDoor.resolve].
String resolvePaywallLocation(String location) =>
    _door?.resolve(location) ?? location;

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

/// Opens the Pro paywall for [source]: the Pro sheet, or a layout. Every
/// place that opens it asks here.
///
/// [isSelfHosted] is the opener's own knowledge of the phone. Only the
/// sheet has a line for it.
Future<void> openProPaywall(
  BuildContext context,
  ProPackSheetSource source, {
  bool isSelfHosted = false,
}) {
  final layoutLocation = _door?.proLayoutLocation(source);
  return layoutLocation == null
      ? openProPackSheet(context, source, isSelfHosted: isSelfHosted)
      : context.push<void>(layoutLocation);
}

/// The one way from a locked feature to a paywall.
///
/// [decision] is `FeatureAccess.decide` for the feature the person reached
/// for, and [source] is where they met the lock. The caller never names a
/// product: a decision that offers Hosted opens the Hosted paywall, one
/// that offers Pro opens the Pro paywall. A decision that is open or
/// confirming opens nothing, because there is nothing to sell.
///
/// [isSelfHosted] is the opener's own knowledge of the phone. Only the Pro
/// sheet has a line for it.
Future<void> openPaywallFor(
  BuildContext context,
  FeatureDecision decision,
  LockSource source, {
  bool isSelfHosted = false,
}) async {
  if (decision is! FeatureLocked) return;
  switch (decision.offer) {
    case Holding.hosted:
      await context.push<void>(hostedPaywallLocation(source.hosted));
    case Holding.pro:
      await openProPaywall(context, source.pro, isSelfHosted: isSelfHosted);
  }
}

/// The location [openPaywallFor] opens, or null when [decision] locks
/// nothing. For a caller that holds a router and no context, such as a
/// sheet that closes itself before the paywall opens.
String? paywallLocationFor(
  FeatureDecision decision,
  LockSource source, {
  bool isSelfHosted = false,
}) {
  if (decision is! FeatureLocked) return null;
  return switch (decision.offer) {
    Holding.hosted => hostedPaywallLocation(source.hosted),
    Holding.pro =>
      _door?.proLayoutLocation(source.pro) ??
          proPackSheetLocation(source.pro, isSelfHosted: isSelfHosted),
  };
}

/// The layout route's gate in a store build: null lets the layout draw.
String? shippedPaywallInsteadOf(Uri layoutLocation) {
  final door = _door;
  if (door != null) return door.shippedInsteadOf(layoutLocation);
  // No door means nothing was set, so the shipped surface it is.
  final query = layoutLocation.queryParameters;
  return PaywallProduct.parse(query['product']) == PaywallProduct.pro
      ? proPackSheetPath
      : paywallLocation(PaywallSource.parse(query['source']));
}
