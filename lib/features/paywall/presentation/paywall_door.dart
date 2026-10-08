import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/paywall_routing.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:critalarm/features/pro_pack/presentation/pro_pack_sheet_page.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The one way into either paywall.
///
/// It reads what [paywallOpeningFor] needs (the remote values, what
/// Developer options set, whether the false alarm intro was shown) and
/// answers with a location: the shipped route, exactly as before, or a
/// layout's, with its intro. Anything that goes wrong while it reads
/// answers with the shipped route.
class PaywallDoor {
  PaywallDoor({
    required this._remoteValue,
    required this._developer,
    required this._hasSeenFalseAlarm,
    required this._markFalseAlarmSeen,
    this._remoteIntroValue = _noIntroValue,
    this._developerIntro = _noDeveloperIntro,
    this._isIntroBuilt = paywallIntroIsBuilt,
  });

  /// The prefs key that says the false alarm intro was shown on this
  /// install. Set once, when a paywall opens on it.
  static const String falseAlarmShownKey = 'paywall.false_alarm_shown';

  static String _noIntroValue(PaywallProduct product) => '';
  static PaywallIntroId? _noDeveloperIntro(PaywallProduct product) => null;

  final String Function(PaywallProduct product) _remoteValue;
  final PaywallLayoutSetting? Function(PaywallProduct product) _developer;
  final String Function(PaywallProduct product) _remoteIntroValue;
  final PaywallIntroId? Function(PaywallProduct product) _developerIntro;
  final bool Function() _hasSeenFalseAlarm;
  final Future<void> Function() _markFalseAlarmSeen;
  final bool Function(PaywallIntroId intro) _isIntroBuilt;

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
      );
      if (opening == null) return null;
      if (opening.intro == PaywallIntroId.falseAlarm) {
        _markFalseAlarmSeen().ignore();
      }
      // An intro this build has no animation for is no intro.
      return _isIntroBuilt(opening.intro)
          ? opening
          : PaywallOpening(opening.layout);
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
    final opening = openingFor(PaywallProduct.hosted, paywallEntryOf(source));
    return opening == null
        ? location
        : paywallLayoutLocation(
            opening.layout,
            PaywallProduct.hosted,
            intro: opening.intro,
            source: source,
          );
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
