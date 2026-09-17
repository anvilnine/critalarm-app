import 'dart:convert';
import 'dart:math';

import 'package:critalarm/core/env/env.dart';
import 'package:critalarm/features/account/domain/entities/account_identity.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// What a provider sheet handed back, before our own server has seen it.
final class ProviderCredential {
  const ProviderCredential({
    required this.idToken,
    this.rawNonce,
    this.email,
  });

  /// Apple's or Google's own id token. Not yet an `identity_token`.
  final String idToken;

  /// Apple only. The unhashed string the server compares the `nonce` claim
  /// against.
  final String? rawNonce;

  final String? email;
}

/// Runs a provider's own sign-in sheet.
///
/// Split out from the repository so a test can stand in for Apple and Google
/// without a handset.
abstract interface class ProviderSignIn {
  bool supports(IdentityProvider provider);

  Future<ProviderCredential> signIn(IdentityProvider provider);

  Future<void> signOut();
}

/// The real sheets: `sign_in_with_apple` on iOS, `google_sign_in` on both.
final class NativeProviderSignIn implements ProviderSignIn {
  NativeProviderSignIn({
    GoogleSignIn? google,
    TargetPlatform? platform,
    String? googleIosClientId,
    String? googleServerClientId,
  }) : _google = google ?? GoogleSignIn.instance,
       _platform = platform ?? defaultTargetPlatform,
       _iosClientId = googleIosClientId ?? Env.googleIosClientId,
       _serverClientId = googleServerClientId ?? Env.googleServerClientId;

  final GoogleSignIn _google;
  final TargetPlatform _platform;
  final String _iosClientId;
  final String _serverClientId;

  bool _googleReady = false;

  @override
  bool supports(IdentityProvider provider) => switch (provider) {
    IdentityProvider.apple => !kIsWeb && _platform == TargetPlatform.iOS,
    IdentityProvider.google => true,
  };

  @override
  Future<ProviderCredential> signIn(IdentityProvider provider) =>
      switch (provider) {
        IdentityProvider.apple => _signInWithApple(),
        IdentityProvider.google => _signInWithGoogle(),
      };

  @override
  Future<void> signOut() => _googleReady ? _google.signOut() : Future.value();

  Future<ProviderCredential> _signInWithApple() async {
    final rawNonce = _randomNonce();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await _appleCredential(rawNonce);
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const IdentitySignInCancelled();
      }
      rethrow;
    }
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw StateError('Apple returned no identity token');
    }
    return ProviderCredential(
      idToken: idToken,
      rawNonce: rawNonce,
      email: credential.email,
    );
  }

  Future<AuthorizationCredentialAppleID> _appleCredential(String rawNonce) {
    return SignInWithApple.getAppleIDCredential(
      // The name is not asked for. Apple only ever hands it over on the very
      // first sign-in for an Apple ID, and nothing in the app shows a name.
      scopes: const [AppleIDAuthorizationScopes.email],
      // Apple copies whatever it is given straight into the `nonce` claim,
      // and the server checks that claim against both the raw string and its
      // SHA-256. So Apple gets the hash and the server gets the raw value.
      // Sending the same string to both fails, and the error says nothing
      // about nonces.
      nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
    );
  }

  Future<ProviderCredential> _signInWithGoogle() async {
    if (!_googleReady) {
      await _google.initialize(
        // The iOS client belongs to iOS alone. Android reads its client from
        // the platform config, so passing one there would be wrong.
        clientId: _platform == TargetPlatform.iOS && _iosClientId.isNotEmpty
            ? _iosClientId
            : null,
        serverClientId: _serverClientId.isNotEmpty ? _serverClientId : null,
      );
      _googleReady = true;
    }
    final GoogleSignInAccount account;
    try {
      account = await _google.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const IdentitySignInCancelled();
      }
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google returned no id token');
    }
    return ProviderCredential(idToken: idToken, email: account.email);
  }

  static String _randomNonce([int length = 32]) {
    const characters =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
  }
}
