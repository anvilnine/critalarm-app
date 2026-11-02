import 'package:critalarm/core/store/services/store_catalog_entry.dart';
import 'package:critalarm/core/store/services/store_customer.dart';

/// What went wrong at the store, in the app's own words.
enum StoreBillingError {
  /// The buyer backed out.
  cancelled,

  /// The device or account may not buy (parental controls, a store policy).
  notAllowed,

  /// The store took the purchase and is holding the payment: Ask to Buy, or
  /// a Play payment that still has to clear.
  pending,

  /// The account already owns it.
  alreadyOwned,

  /// The store could not be reached.
  network,

  /// The build's store key or setup is wrong.
  badConfiguration,

  /// The store reported a problem of its own.
  storeProblem,

  /// Anything else the store reported.
  other,
}

/// A problem the store itself reported. Anything else a [StoreBilling] call
/// throws is a fault in the app, not an answer from the store.
final class StoreBillingException implements Exception {
  const StoreBillingException(this.error, [this.message]);

  final StoreBillingError error;

  /// The store's own words, where it gave some.
  final String? message;

  @override
  String toString() => 'StoreBillingException(${error.name}, $message)';
}

/// The store that sells Cloud and the Pro pack, as feature code sees it.
///
/// Every call but [identifyAccount] throws a [StateError] while the store
/// is not set up. The reads, [purchase] and [restore] throw a
/// [StoreBillingException] when the store reports a problem.
abstract interface class StoreBilling {
  /// Whether the store was set up for this run. A build with no store key
  /// never is.
  bool get isConfigured;

  /// What the store knows about this account, each time it changes.
  Stream<StoreCustomer> get customerChanges;

  Future<StoreCustomer> readCustomer();

  Future<StoreOfferings> readOfferings();

  /// Buys [entry], one the last [readOfferings] handed out.
  Future<StoreCustomer> purchase(StoreCatalogEntry entry);

  /// Asks the store to hand back what this account already bought.
  Future<StoreCustomer> restore();

  /// Ties purchases to our account id. Safe before the store is set up:
  /// the id is kept and used once it is.
  Future<void> identifyAccount(String accountId);

  /// Goes back to an anonymous store user.
  Future<void> logOut();

  /// Drops the store's cached [readCustomer] answer, so the next read asks
  /// the store.
  Future<void> invalidateCustomerCache();
}
