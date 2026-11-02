import 'package:critalarm/core/store/play_apple/revenuecat_billing.dart';
import 'package:critalarm/core/store/services/manage_subscription.dart';
import 'package:critalarm/core/store/services/store_customer.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// [ManageSubscription] as RevenueCat's Customer Center, the native screen
/// on Google Play and the App Store. It is the one thing the app still
/// takes from `purchases_ui_flutter`.
final class RevenueCatCustomerCenter implements ManageSubscription {
  const RevenueCatCustomerCenter();

  @override
  Future<void> open({
    Future<void> Function(StoreCustomer customer)? onRestored,
  }) => RevenueCatUI.presentCustomerCenter(
    onRestoreCompleted: (info) async {
      await onRestored?.call(storeCustomerOf(info));
    },
  );
}
