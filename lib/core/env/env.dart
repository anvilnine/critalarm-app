import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env', obfuscate: true)
abstract class Env {
  /// RevenueCat hands out one public SDK key per store, and the SDK refuses a
  /// key from the other one, so the two cannot share a field. Android's starts
  /// with `goog_`, Apple's with `appl_`. A `test_` key is the Test Store, and
  /// the SDK throws on it in a release build.
  @EnviedField(
    varName: 'REVENUECAT_ANDROID_API_KEY',
    obfuscate: true,
    defaultValue: '',
  )
  static final String revenueCatAndroidApiKey = _Env.revenueCatAndroidApiKey;

  @EnviedField(
    varName: 'REVENUECAT_IOS_API_KEY',
    obfuscate: true,
    defaultValue: '',
  )
  static final String revenueCatIosApiKey = _Env.revenueCatIosApiKey;

  /// The iOS OAuth client for Google sign-in. iOS reads its client from here
  /// rather than from a bundled plist, so nothing about the account lives in
  /// a file this public repo would carry.
  @EnviedField(
    varName: 'GOOGLE_IOS_CLIENT_ID',
    obfuscate: true,
    defaultValue: '',
  )
  static final String googleIosClientId = _Env.googleIosClientId;

  /// The web client, passed as the server client on both platforms. It is
  /// what makes Google mint an id token our own server can check.
  @EnviedField(
    varName: 'GOOGLE_SERVER_CLIENT_ID',
    obfuscate: true,
    defaultValue: '',
  )
  static final String googleServerClientId = _Env.googleServerClientId;
}
