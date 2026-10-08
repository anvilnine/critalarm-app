import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_thanks.dart';
import 'package:critalarm/core/telemetry/analytics_events.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';

/// The events a paywall layout sends. Nothing is sent unless the user
/// turned analytics on in Settings, which [TelemetryGate.logEvent] checks.
///
/// A Hosted layout sends the events of the shipped paywall and a Pro layout
/// those of the Pro sheet, under the same names with the same parameters,
/// so one funnel reads both. Each also carries `layout`, `intro`, `thanks`
/// and `product`. The shipped surfaces keep `PaywallAnalytics` and
/// `ProPackAnalytics` and send exactly what they always have.
///
/// No event carries a price, a store product or a topic. A layout is not a
/// paywall variant, so none carries `variant`.
final class PaywallLayoutAnalytics {
  const PaywallLayoutAnalytics(
    this._gate, {
    required this.layout,
    required this.isHosted,
    this.intro = PaywallIntroId.none,
    this.thanks = PaywallThanksId.none,
  });

  final TelemetryGate _gate;

  /// The layout the route asked for.
  final PaywallLayoutId layout;

  /// The intro that played before it, `none` when none did.
  final PaywallIntroId intro;

  /// What plays after a confirmed purchase, `none` when nothing does.
  final PaywallThanksId thanks;

  /// Hosted, or Pro.
  final bool isHosted;

  static const String hostedProduct = 'hosted';
  static const String proProduct = 'pro';

  Map<String, Object?> _with(Map<String, Object?> parameters) => {
    ...parameters,
    'layout': layout.key,
    'intro': intro.key,
    'thanks': thanks.key,
    'product': isHosted ? hostedProduct : proProduct,
  };

  /// [source] is the wire name of what opened the paywall.
  Future<void> viewed({required String source}) => _gate.logEvent(
    isHosted
        ? AnalyticsEvents.paywallViewed
        : AnalyticsEvents.proPackSheetOpened,
    _with({'source': source}),
  );

  /// [plan] is `yearly` or `monthly`. Pro has one thing to buy and names
  /// no plan.
  Future<void> purchaseStarted({String? plan}) => _gate.logEvent(
    isHosted
        ? AnalyticsEvents.paywallPurchaseStarted
        : AnalyticsEvents.proPackPurchaseStarted,
    _with({'plan': ?plan}),
  );

  /// Hosted: the store took the purchase.
  Future<void> hostedPurchaseCompleted({required String plan}) =>
      _gate.logEvent(
        AnalyticsEvents.paywallPurchaseCompleted,
        _with({'plan': plan}),
      );

  /// Hosted: [reason] is `cancelled` or `failed`.
  Future<void> hostedPurchaseFailed({
    required String plan,
    required String reason,
  }) => _gate.logEvent(
    AnalyticsEvents.paywallPurchaseFailed,
    _with({'plan': plan, 'reason': reason}),
  );

  /// Pro: [result] is `held` or `checking`.
  Future<void> proPurchaseFinished({required String result}) => _gate.logEvent(
    AnalyticsEvents.proPackPurchaseFinished,
    _with({'result': result}),
  );

  /// [result] is `held`, `none` or `checking`, and for Hosted also `failed`.
  Future<void> restoreFinished({required String result}) => _gate.logEvent(
    isHosted
        ? AnalyticsEvents.paywallRestoreFinished
        : AnalyticsEvents.proPackRestoreFinished,
    _with({'result': result}),
  );

  /// [source] is the same word [viewed] carried.
  Future<void> closed({required String source}) => _gate.logEvent(
    isHosted ? AnalyticsEvents.paywallClosed : AnalyticsEvents.proPackClosed,
    _with({'source': source}),
  );

  /// The step after a purchase came on screen. [kind] is `purchase`,
  /// `restore` or `owned` (the product was already held).
  Future<void> thanksShown({required String kind}) => _gate.logEvent(
    AnalyticsEvents.paywallThanksShown,
    _with({'kind': kind}),
  );

  /// The buyer left it. [how] is `button` or `away` (back, a swipe).
  /// [skipped] says whether a tap cut the show short, sent as 1 or 0.
  Future<void> thanksLeft({
    required String kind,
    required String how,
    required bool skipped,
  }) => _gate.logEvent(
    AnalyticsEvents.paywallThanksLeft,
    _with({'kind': kind, 'how': how, 'skipped': skipped ? 1 : 0}),
  );
}
