import 'dart:convert';

import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/features/account/data/services/provider_sign_in.dart';
import 'package:critalarm/features/account/domain/entities/account_identity.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/domain/repositories/identity_repository.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Swaps a provider's id token for one of our own sessions, and remembers it.
///
/// The account routes want an `identity_token` issued by our server, so the
/// provider sheet is only the first half of signing in.
final class HttpIdentityRepository implements IdentityRepository {
  const HttpIdentityRepository({
    required this.httpClient,
    required this.sessions,
    required this.prefs,
    required this.providers,
  });

  final http.Client httpClient;
  final ApiSessionStore sessions;
  final SharedPreferences prefs;
  final ProviderSignIn providers;

  static const _tokenKey = 'identity_session_token';
  static const _providerKey = 'identity_provider';
  static const _emailKey = 'identity_email';
  static const _accountKey = 'identity_account_id';

  /// The auth surface answers 200 here whenever it is mounted at all, so it
  /// is the cheap way to ask whether sign-in exists. The session itself is at
  /// `/api/auth/get-session`, never `/api/auth/session`, which 404s and reads
  /// exactly like sign-in being switched off.
  static const probePath = 'api/auth/ok';
  static const exchangePath = 'api/auth/sign-in/social';

  @override
  bool supports(IdentityProvider provider) => providers.supports(provider);

  @override
  Future<IdentitySession> signIn(IdentityProvider provider) async {
    final session = await sessions.read();
    if (session == null) throw StateError('No API session configured');
    final credential = await providers.signIn(provider);
    final response = await httpClient.post(
      _resolve(session.baseUri, exchangePath),
      headers: const {
        'accept': 'application/json',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'provider': provider.wireValue,
        'idToken': {
          'token': credential.idToken,
          if (credential.rawNonce != null) 'nonce': credential.rawNonce,
        },
      }),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: response.reasonPhrase ?? 'Sign-in failed',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final user = json['user'] as Map<String, dynamic>?;
    final identity = IdentitySession(
      token: json['token'] as String,
      provider: provider,
      email: credential.email ?? user?['email'] as String?,
    );
    await prefs.setString(_tokenKey, identity.token);
    await prefs.setString(_providerKey, provider.wireValue);
    final email = identity.email;
    if (email != null) await prefs.setString(_emailKey, email);
    return identity;
  }

  @override
  Future<IdentitySession?> readSession() async {
    final token = prefs.getString(_tokenKey);
    final provider = _readProvider();
    if (token == null || provider == null) return null;
    return IdentitySession(
      token: token,
      provider: provider,
      email: prefs.getString(_emailKey),
    );
  }

  @override
  Future<AccountIdentity?> readIdentity() async {
    final provider = _readProvider();
    final accountId = prefs.getString(_accountKey);
    if (provider == null || accountId == null) return null;
    return AccountIdentity(
      provider: provider,
      accountId: accountId,
      email: prefs.getString(_emailKey),
    );
  }

  @override
  Future<void> saveIdentity(AccountIdentity identity) async {
    await prefs.setString(_providerKey, identity.provider.wireValue);
    await prefs.setString(_accountKey, identity.accountId);
    final email = identity.email;
    if (email == null) {
      await prefs.remove(_emailKey);
    } else {
      await prefs.setString(_emailKey, email);
    }
  }

  @override
  Future<void> clearSession() async {
    await prefs.remove(_tokenKey);
    await prefs.remove(_providerKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_accountKey);
    await providers.signOut();
  }

  IdentityProvider? _readProvider() {
    final raw = prefs.getString(_providerKey);
    for (final provider in IdentityProvider.values) {
      if (provider.wireValue == raw) return provider;
    }
    return null;
  }

  /// The auth surface hangs off the same host as the API, which can carry a
  /// path prefix of its own.
  static Uri _resolve(Uri base, String path) {
    final prefix = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final authority = base.hasPort ? '${base.host}:${base.port}' : base.host;
    return Uri.parse('${base.scheme}://$authority$prefix/$path');
  }
}
