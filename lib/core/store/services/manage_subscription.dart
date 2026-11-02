import 'package:critalarm/core/store/services/store_customer.dart';

/// The store's own place to see, change or cancel the paid plan.
///
/// On the App Store and Google Play it is RevenueCat's Customer Center. A
/// store without one opens its subscriptions page instead and never calls
/// `onRestored`.
// ignore: one_member_abstracts
abstract interface class ManageSubscription {
  /// Opens it and returns once it closes. [onRestored] runs when the person
  /// restored purchases from inside it.
  Future<void> open({
    Future<void> Function(StoreCustomer customer)? onRestored,
  });
}
