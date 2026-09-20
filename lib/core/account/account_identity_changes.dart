import 'package:flutter/foundation.dart';

/// Says that the stored account identity changed, so screens can look again.
///
/// Signing in, signing out, linking a second provider and deleting the account
/// all end up writing through the identity repository, so the repository is
/// what bumps this. Nobody at a call site has to remember to do it.
///
/// The app runs on [appAccountIdentityChanges]. A test passes its own instance
/// instead, so one test never hears another test's bumps.
class AccountIdentityChanges extends ChangeNotifier {
  /// Tells every listener the stored identity is not what it was.
  void bump() => notifyListeners();
}

/// The one the app is wired to in `di.dart`.
final AccountIdentityChanges appAccountIdentityChanges =
    AccountIdentityChanges();
