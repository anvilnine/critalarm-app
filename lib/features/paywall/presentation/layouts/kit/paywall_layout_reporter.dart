import 'dart:async';

import 'package:critalarm/core/telemetry/paywall_layout_analytics.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/gen/locale_keys.g.dart';

/// How a purchase or a restore ended, read from the state it rested in.
enum PaywallBuyOutcome {
  /// This install has the product.
  held,

  /// The store finished and the app is still confirming it.
  checking,

  /// The store is holding the payment. Nothing was paid yet.
  pending,

  /// A restore found nothing.
  none,

  /// The buyer backed out.
  cancelled,

  /// The store reported a problem.
  failed,
}

/// The outcome [state] stands for, or null while the store is still busy
/// and nothing can be said.
PaywallBuyOutcome? paywallBuyOutcomeOf(PaywallBuyState state) {
  switch (state.status) {
    case PaywallBuyStatus.done:
      return PaywallBuyOutcome.held;
    case PaywallBuyStatus.checking:
      return state.messageKey == LocaleKeys.purchase_errors_payment_pending
          ? PaywallBuyOutcome.pending
          : PaywallBuyOutcome.checking;
    case PaywallBuyStatus.failed:
      return PaywallBuyOutcome.failed;
    case PaywallBuyStatus.ready:
    case PaywallBuyStatus.notOnSale:
      return switch (state.messageKey) {
        LocaleKeys.paywall_kit_nothing_to_restore => PaywallBuyOutcome.none,
        LocaleKeys.paywall_kit_failed => PaywallBuyOutcome.failed,
        _ => PaywallBuyOutcome.cancelled,
      };
    case PaywallBuyStatus.loading:
    case PaywallBuyStatus.purchasing:
      return null;
  }
}

/// Turns what one paywall layout did into analytics events.
///
/// It sends an event only where the shipped surface for the same product
/// sends one, plus the restore and the close, which only layouts report.
class PaywallLayoutReporter implements PaywallBuyReporter {
  PaywallLayoutReporter(this._analytics, {required this.source});

  final PaywallLayoutAnalytics _analytics;

  /// The wire name of what opened the paywall.
  final String source;

  void viewed() => unawaited(_analytics.viewed(source: source));

  @override
  void started(PaywallBuyAction action, PaywallBuyState state) {
    // The shipped surfaces have no event for a restore that starts.
    if (action != PaywallBuyAction.purchase) return;
    unawaited(
      _analytics.purchaseStarted(
        plan: _analytics.isHosted ? state.selectedId : null,
      ),
    );
  }

  @override
  void finished(PaywallBuyAction action, PaywallBuyState state) {
    final outcome = paywallBuyOutcomeOf(state);
    if (outcome == null) return;
    final event = switch (action) {
      PaywallBuyAction.restore => _restore(outcome),
      PaywallBuyAction.purchase =>
        _analytics.isHosted
            ? _hostedPurchase(outcome, state.selectedId)
            : _proPurchase(outcome),
    };
    if (event != null) unawaited(event);
  }

  @override
  void closed() => unawaited(_analytics.closed(source: source));

  /// The shipped paywall says completed as soon as the store takes the
  /// purchase, and failed for everything else.
  Future<void>? _hostedPurchase(PaywallBuyOutcome outcome, String? plan) {
    if (plan == null) return null;
    return switch (outcome) {
      PaywallBuyOutcome.held || PaywallBuyOutcome.checking =>
        _analytics.hostedPurchaseCompleted(plan: plan),
      PaywallBuyOutcome.cancelled => _analytics.hostedPurchaseFailed(
        plan: plan,
        reason: 'cancelled',
      ),
      PaywallBuyOutcome.pending ||
      PaywallBuyOutcome.failed ||
      PaywallBuyOutcome.none => _analytics.hostedPurchaseFailed(
        plan: plan,
        reason: 'failed',
      ),
    };
  }

  /// The Pro sheet reports a purchase only once the store has finished.
  Future<void>? _proPurchase(PaywallBuyOutcome outcome) => switch (outcome) {
    PaywallBuyOutcome.held => _analytics.proPurchaseFinished(result: 'held'),
    PaywallBuyOutcome.checking => _analytics.proPurchaseFinished(
      result: 'checking',
    ),
    PaywallBuyOutcome.pending ||
    PaywallBuyOutcome.none ||
    PaywallBuyOutcome.cancelled ||
    PaywallBuyOutcome.failed => null,
  };

  Future<void>? _restore(PaywallBuyOutcome outcome) => switch (outcome) {
    PaywallBuyOutcome.held => _analytics.restoreFinished(result: 'held'),
    PaywallBuyOutcome.none => _analytics.restoreFinished(result: 'none'),
    PaywallBuyOutcome.checking ||
    PaywallBuyOutcome.pending => _analytics.restoreFinished(result: 'checking'),
    // The Pro sheet says nothing when the store itself fails a restore.
    PaywallBuyOutcome.failed =>
      _analytics.isHosted ? _analytics.restoreFinished(result: 'failed') : null,
    PaywallBuyOutcome.cancelled => null,
  };
}
