import 'package:critalarm/core/env/env.dart';
import 'package:critalarm/core/store/services/google_sign_in_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// [GoogleSignInSheet] as the native `google_sign_in` sheet, on Android
/// with Google Play services, on iOS and on macOS.
final class NativeGoogleSignInSheet implements GoogleSignInSheet {
  NativeGoogleSignInSheet({
    required this._platform,
    GoogleSignIn? google,
    String? iosClientId,
    String? serverClientId,
  }) : _google = google ?? GoogleSignIn.instance,
       _iosClientId = iosClientId ?? Env.googleIosClientId,
       _serverClientId = serverClientId ?? Env.googleServerClientId;

  final TargetPlatform _platform;
  final GoogleSignIn _google;
  final String _iosClientId;
  final String _serverClientId;

  bool get _isApple =>
      _platform == TargetPlatform.iOS || _platform == TargetPlatform.macOS;

  bool _ready = false;

  @override
  Future<GoogleSheetAnswer> signIn() async {
    if (!_ready) {
      await _google.initialize(
        // The iOS client belongs to the Apple apps. The Mac app has the same
        // bundle id, and Google's macOS sign-in takes an iOS client. Android
        // reads its client from the platform config, so passing one there
        // would be wrong.
        clientId: _isApple && _iosClientId.isNotEmpty ? _iosClientId : null,
        serverClientId: _serverClientId.isNotEmpty ? _serverClientId : null,
      );
      _ready = true;
    }
    final GoogleSignInAccount account;
    try {
      account = await _google.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const SignInSheetCancelled();
      }
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google returned no id token');
    }
    return GoogleSheetAnswer(idToken: idToken, email: account.email);
  }

  @override
  Future<void> signOut() => _ready ? _google.signOut() : Future.value();
}
