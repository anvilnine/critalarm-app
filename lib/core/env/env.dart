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
}
