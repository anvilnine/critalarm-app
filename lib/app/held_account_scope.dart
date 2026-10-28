import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/store/held_scope.dart';
import 'package:critalarm/features/account/data/repositories/http_identity_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The scope the phone's held data belongs to right now: the saved server and
/// the account the phone is on.
///
/// The account is the one the person signed in to when they are signed in
/// (`HttpIdentityRepository.accountIdKey`), and the device's own account
/// otherwise. A sign-in that attaches, switches or merges changes the account
/// at once and saves it there, while the device's registration (and the
/// account id saved with it) catches up only at the next registration. Reading
/// the device's id alone would file a signed-in person's data under the
/// anonymous account until then.
///
/// The topic list and the archive of incidents and messages both read their
/// scope from here.
class HeldAccountScope {
  HeldAccountScope({
    required this._prefs,
    required this._devices,
    required this._serverUrl,
  });

  final SharedPreferences _prefs;
  final DeviceIdentityStore _devices;
  final Future<String?> Function() _serverUrl;

  Future<String?> call() async => heldScopeFor(
    serverUrl: await _serverUrl(),
    accountId: await accountId(),
  );

  /// The scope of [accountId] on the saved server.
  Future<String?> forAccount(String accountId) async =>
      heldScopeFor(serverUrl: await _serverUrl(), accountId: accountId);

  /// The account the phone is on, or null on a server with no accounts.
  Future<String?> accountId() async =>
      _prefs.getString(HttpIdentityRepository.accountIdKey) ??
      (await _devices.readOrCreate()).accountId;
}
