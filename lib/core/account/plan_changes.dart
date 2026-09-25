import 'package:flutter/foundation.dart';

/// Says that this device's plan may have changed, so screens can look again.
///
/// Two things move it:
///
/// - The store. RevenueCat knows about a purchase the moment it goes through,
///   seconds before its webhook reaches our server and the registered tier
///   flips. [storeSaysPro] carries that, so the app turns Pro right away
///   instead of making the buyer wait on the server.
/// - The server. A registration that comes back with a different tier or
///   different caps calls [bump].
///
/// The app runs on [appPlanChanges]. A test passes its own instance instead,
/// so one test never hears another test's changes.
class PlanChanges extends ChangeNotifier {
  bool _storeSaysPro = false;

  /// True while the store reports an active Pro entitlement for this account.
  bool get storeSaysPro => _storeSaysPro;

  /// Records what the store says. Tells listeners only when it changed.
  void setStoreSaysPro({required bool value}) {
    if (value == _storeSaysPro) return;
    _storeSaysPro = value;
    notifyListeners();
  }

  /// Tells every listener the saved tier or caps are not what they were.
  void bump() => notifyListeners();
}

/// The one the app is wired to in `di.dart`.
final PlanChanges appPlanChanges = PlanChanges();
