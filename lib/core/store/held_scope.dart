import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The scope a list held on the phone belongs to: one server and one account.
///
/// A hash, so neither the address nor the account id is written a second
/// time. Null when no server is saved, because a list read for no server
/// belongs to nobody.
///
/// A self-hosted server has no accounts, so its scope is the address alone
/// ([accountId] null). On a hosted or relay server the account id is part of
/// it, which is what makes a sign-out, a sign-in as somebody else and an
/// account switch each hand the next reader a different scope.
String? heldScopeFor({required String? serverUrl, required String? accountId}) {
  final server = serverUrl?.trim().toLowerCase();
  if (server == null || server.isEmpty) return null;
  final address = server.endsWith('/')
      ? server.substring(0, server.length - 1)
      : server;
  final text = '$address|${accountId ?? ''}';
  return sha256.convert(utf8.encode(text)).toString().substring(0, 16);
}
