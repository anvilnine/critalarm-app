import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/store/services/sign_in_options.dart';

/// The sign-in providers of a Google Play or App Store build.
///
/// Apple is offered in the native iPhone and Mac apps only. On Android it
/// needs a browser redirect through a Services ID and a server route to catch
/// Apple's form POST, and the contract has neither, so Android shows Google
/// alone.
final class PlayAppleSignInOptions implements SignInOptions {
  const PlayAppleSignInOptions(this._capabilities);

  final PlatformCapabilities _capabilities;

  @override
  List<SignInProvider> get providers => [
    if (_capabilities.isApple) SignInProvider.apple,
    SignInProvider.google,
  ];
}
