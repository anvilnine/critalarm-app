import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env', obfuscate: true)
abstract class Env {
  @EnviedField(
    varName: 'REVENUECAT_API_KEY',
    obfuscate: true,
    defaultValue: '',
  )
  static final String revenueCatApiKey = _Env.revenueCatApiKey;

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
