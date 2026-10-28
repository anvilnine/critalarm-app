import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Service encapsulating RevenueCat SDK lifecycle and direct interactions.
class RevenueCatService {
  RevenueCatService();

  bool _isConfigured = false;
  String? _accountId;
  Future<void> _login = Future<void>.value();

  Future<void> identifyAccount(String accountId) async {
    _accountId = accountId;
    if (!_isConfigured) return;
    final previous = _login;
    _login = () async {
      try {
        await previous;
      } on Object catch (_) {
        // A later registration retries a failed login.
      }
      await logIn(accountId);
    }();
    await _login;
  }

  Future<void> invalidateCustomerInfoCache() async {
    _ensureConfigured();
    await Purchases.invalidateCustomerInfoCache();
  }

  final _customerInfoStreamController =
      StreamController<CustomerInfo>.broadcast();

  /// Whether the RevenueCat SDK has been initialized and configured.
  bool get isConfigured => _isConfigured;

  /// Broadcast stream of customer information updates.
  Stream<CustomerInfo> get customerInfoStream =>
      _customerInfoStreamController.stream;

  /// Initializes the RevenueCat SDK with the provided API key.
  Future<void> initialize({
    required String apiKey,
    String? appUserId,
  }) async {
    if (_isConfigured) return;
    _accountId ??= appUserId;

    if (kDebugMode) {
      await Purchases.setLogLevel(LogLevel.debug);
    } else {
      await Purchases.setLogLevel(LogLevel.info);
    }

    final configuration = PurchasesConfiguration(apiKey)
      ..appUserID = _accountId;

    await Purchases.configure(configuration);
    _isConfigured = true;
    final accountId = _accountId;
    if (accountId != null) await identifyAccount(accountId);

    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      if (!_customerInfoStreamController.isClosed) {
        _customerInfoStreamController.add(customerInfo);
      }
    });
  }

  /// Retrieves current customer info.
  Future<CustomerInfo> getCustomerInfo() async {
    _ensureConfigured();
    return Purchases.getCustomerInfo();
  }

  /// Fetches available offerings from RevenueCat.
  Future<Offerings> getOfferings() async {
    _ensureConfigured();
    return Purchases.getOfferings();
  }

  /// Executes purchase for a package using modern [PurchaseParams].
  Future<CustomerInfo> purchasePackage(Package package) async {
    _ensureConfigured();
    await _login;
    if (_accountId == null) {
      throw StateError('No RevenueCat account configured');
    }
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return result.customerInfo;
  }

  /// Restores previous transactions.
  Future<CustomerInfo> restorePurchases() async {
    _ensureConfigured();
    await _login;
    if (_accountId == null) {
      throw StateError('No RevenueCat account configured');
    }
    return Purchases.restorePurchases();
  }

  /// Logs in a user with their distinct App User ID (e.g., account id).
  Future<CustomerInfo> logIn(String appUserId) async {
    _ensureConfigured();
    final result = await Purchases.logIn(appUserId);
    return result.customerInfo;
  }

  /// Logs out the user, returning to an anonymous user ID.
  Future<CustomerInfo> logOut() async {
    _ensureConfigured();
    return Purchases.logOut();
  }

  void _ensureConfigured() {
    if (!_isConfigured) {
      throw StateError(
        'RevenueCatService must be configured before '
        'invoking purchases operations.',
      );
    }
  }

  /// Disposes active resources.
  Future<void> dispose() async {
    await _customerInfoStreamController.close();
  }
}
