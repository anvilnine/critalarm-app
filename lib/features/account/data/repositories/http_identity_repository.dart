import 'dart:convert';

import 'package:critalarm/core/account/account_identity_changes.dart';
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
  HttpIdentityRepository({
    required this.httpClient,
    required this.sessions,
    required this.prefs,
    required this.providers,
    AccountIdentityChanges? identityChanges,
  }) : identityChanges = identityChanges ?? appAccountIdentityChanges;

  final http.Client httpClient;
  final ApiSessionStore sessions;
  final SharedPreferences prefs;
  final ProviderSignIn providers;

  /// Bumped whenever the stored identity changes, so screens that show a
  /// signed-in or signed-out state look again on their own.
  final AccountIdentityChanges identityChanges;

  static const _tokenKey = 'identity_session_token';
  static const _providerKey = 'identity_provider';
  static const _emailKey = 'identity_email';
  static const _accountKey = 'identity_account_id';

  /// Every provider that reaches the account, comma separated. Missing on an
  /// install saved before linking existed, which reads as the one provider in
  /// [_providerKey].
  static const _providersKey = 'identity_providers';

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
      providers: _readProviders(),
    );
  }

  @override
  Future<void> saveIdentity(AccountIdentity identity) async {
    await prefs.setString(_providerKey, identity.provider.wireValue);
    await prefs.setString(_accountKey, identity.accountId);
    await prefs.setString(
      _providersKey,
      identity.providers.map((p) => p.wireValue).join(','),
    );
    final email = identity.email;
    if (email == null) {
      await prefs.remove(_emailKey);
    } else {
      await prefs.setString(_emailKey, email);
    }
    identityChanges.bump();
  }

  @override
  Future<void> clearSession() async {
    await prefs.remove(_tokenKey);
    await prefs.remove(_providerKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_accountKey);
    await prefs.remove(_providersKey);
    await providers.signOut();
    identityChanges.bump();
  }

  /// The saved provider set, or null when nothing was saved, which is every
  /// install made before linking existed.
  Set<IdentityProvider>? _readProviders() {
    final raw = prefs.getString(_providersKey);
    if (raw == null || raw.isEmpty) return null;
    final saved = <IdentityProvider>{};
    for (final name in raw.split(',')) {
      for (final provider in IdentityProvider.values) {
        if (provider.wireValue == name) saved.add(provider);
      }
    }
    return saved.isEmpty ? null : saved;
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
