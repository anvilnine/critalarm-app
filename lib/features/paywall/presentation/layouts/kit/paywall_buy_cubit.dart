import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Where a purchase stands. One list for both products.
enum PaywallBuyStatus {
  /// Asking the store what is on sale.
  loading,

  /// The options are in and one is picked.
  ready,

  /// Nothing to buy. Restore is still there.
  notOnSale,

  /// The store is busy with a purchase or a restore.
  purchasing,

  /// The store finished and the app is confirming it. For Pro that is the
  /// relay, which has the only say on whether the pack is held. Paused, it
  /// is also where a payment the store is holding rests.
  checking,

  /// This install has the product.
  done,

  /// The store reported a problem. `messageKey` says it in plain words.
  failed,
}

/// One thing to pick in the plan picker. Every string is ready to draw.
@immutable
class PaywallPlanOption {
  const PaywallPlanOption({
    required this.id,
    required this.title,
    required this.price,
    this.perPeriodLine,
    this.savingLabel,
    this.renewalLine,
  });

  /// The ids of the two Hosted options. A Pro option carries the store's
  /// own handle.
  static const String yearlyId = 'yearly';
  static const String monthlyId = 'monthly';

  final String id;
  final String title;

  /// The billed amount, as the store wrote it. Never built or parsed here.
  final String price;

  /// A smaller figure that follows the price, such as the per month figure
  /// of a yearly plan.
  final String? perPeriodLine;

  /// "Save 33%", only when the store prices show a saving.
  final String? savingLabel;

  /// How long one purchase lasts and when it renews. Hosted only.
  final String? renewalLine;

  bool get isYearly => id == yearlyId;

  @override
  bool operator ==(Object other) =>
      other is PaywallPlanOption &&
      other.id == id &&
      other.title == title &&
      other.price == price &&
      other.perPeriodLine == perPeriodLine &&
      other.savingLabel == savingLabel &&
      other.renewalLine == renewalLine;

  @override
  int get hashCode =>
      Object.hash(id, title, price, perPeriodLine, savingLabel, renewalLine);

  @override
  String toString() => 'PaywallPlanOption($id)';
}

/// Everything the buy block draws from.
@immutable
class PaywallBuyState {
  const PaywallBuyState({
    required this.product,
    this.status = PaywallBuyStatus.loading,
    this.options = const [],
    this.selectedId,
    this.messageKey,
    this.isPaused = false,
  });

  final PaywallProduct product;
  final PaywallBuyStatus status;
  final List<PaywallPlanOption> options;
  final String? selectedId;

  /// A string key for one plain line under the plans: why a purchase
  /// failed, that a restore found nothing, that a check is still open.
  final String? messageKey;

  /// True when [status] is `checking` and the app has stopped asking on its
  /// own. The block then offers one button to ask again.
  final bool isPaused;

  PaywallPlanOption? get selected {
    for (final option in options) {
      if (option.id == selectedId) return option;
    }
    return null;
  }

  /// Whether the store or the confirming is running right now.
  bool get isBusy =>
      status == PaywallBuyStatus.loading ||
      status == PaywallBuyStatus.purchasing ||
      (status == PaywallBuyStatus.checking && !isPaused);

  bool get canBuy =>
      (status == PaywallBuyStatus.ready || status == PaywallBuyStatus.failed) &&
      selected != null;

  /// Restore is there whenever the block rests without the product.
  bool get canRestore => switch (status) {
    PaywallBuyStatus.ready ||
    PaywallBuyStatus.notOnSale ||
    PaywallBuyStatus.failed => true,
    PaywallBuyStatus.checking => isPaused,
    PaywallBuyStatus.loading ||
    PaywallBuyStatus.purchasing ||
    PaywallBuyStatus.done => false,
  };

  PaywallBuyState copyWith({
    PaywallBuyStatus? status,
    List<PaywallPlanOption>? options,
    String? selectedId,
    String? messageKey,
    bool isPaused = false,
  }) => PaywallBuyState(
    product: product,
    status: status ?? this.status,
    options: options ?? this.options,
    selectedId: selectedId ?? this.selectedId,
    // A message belongs to the step that set it, so it never carries over.
    messageKey: messageKey,
    isPaused: isPaused,
  );

  @override
  bool operator ==(Object other) =>
      other is PaywallBuyState &&
      other.product == product &&
      other.status == status &&
      listEquals(other.options, options) &&
      other.selectedId == selectedId &&
      other.messageKey == messageKey &&
      other.isPaused == isPaused;

  @override
  int get hashCode => Object.hash(
    product,
    status,
    Object.hashAll(options),
    selectedId,
    messageKey,
    isPaused,
  );

  @override
  String toString() =>
      'PaywallBuyState(${product.key}, $status, options: ${options.length}, '
      'selected: $selectedId, message: $messageKey, paused: $isPaused)';
}

/// A trip to the store the buyer asked for.
enum PaywallBuyAction { purchase, restore }

/// Hears what the buyer did on one paywall, to report it. The route sets
/// it on the cubit. It draws nothing and changes no state.
abstract interface class PaywallBuyReporter {
  /// The buyer asked for [action]. [state] is the state it started from.
  void started(PaywallBuyAction action, PaywallBuyState state);

  /// [action] came to rest in [state], or the paywall closed on it.
  void finished(PaywallBuyAction action, PaywallBuyState state);

  /// The paywall went away.
  void closed();
}

/// The one thing every layout buys through, whatever it sells.
///
/// A layout never calls it: the buy block does. There is one small class
/// per product behind it, and one for a build that skips the store.
abstract class PaywallBuyCubit extends Cubit<PaywallBuyState> {
  PaywallBuyCubit(PaywallProduct product)
    : super(PaywallBuyState(product: product));

  /// Reads what is on sale. Called once when the paywall opens.
  Future<void> load();

  /// Picks the option [id] names. An unknown id changes nothing.
  void select(String id) {
    if (state.isBusy || state.status == PaywallBuyStatus.done) return;
    if (id == state.selectedId) return;
    if (!state.options.any((option) => option.id == id)) return;
    emit(state.copyWith(status: state.status, selectedId: id));
  }

  /// Buys the picked option.
  Future<void> buy();

  Future<void> restore();

  /// Asks again after a check that paused. Does nothing in any other state.
  Future<void> checkAgain();

  /// Set by the route that shows this paywall. Null reports nothing.
  PaywallBuyReporter? reporter;

  /// The purchase or restore that has not come to rest yet.
  PaywallBuyAction? _running;

  /// Every `buy` and `restore` calls this once it is past its own guard
  /// and before it shows a state.
  @protected
  void began(PaywallBuyAction action) {
    _running = action;
    reporter?.started(action, state);
  }

  /// Emits unless the paywall already closed.
  @protected
  void show(PaywallBuyState next) {
    if (isClosed) return;
    emit(next);
    final running = _running;
    if (running == null || next.isBusy) return;
    _running = null;
    reporter?.finished(running, next);
  }

  @override
  Future<void> close() {
    final running = _running;
    _running = null;
    if (running != null) reporter?.finished(running, state);
    reporter?.closed();
    reporter = null;
    return super.close();
  }
}
