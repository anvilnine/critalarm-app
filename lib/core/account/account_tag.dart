import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The tag a note on this phone is kept under for [accountId]: a hash, so
/// the account id itself is not written a second time. Null for an account
/// that is not known.
///
/// Preferences can travel to another phone in a backup, and they outlive a
/// sign-out. A note that says something about a plan is written with this
/// tag next to it, and counts only while the tag is the one of the account
/// the phone is on now ([noteIsForAccount]).
String? accountTagFor(String? accountId) {
  if (accountId == null || accountId.isEmpty) return null;
  return sha256.convert(utf8.encode(accountId)).toString().substring(0, 16);
}

/// Whether a note tagged [noteTag] counts for the account tagged
/// [accountTag]. A note with no tag, and any note while the account is not
/// known, is no note at all.
bool noteIsForAccount({
  required String? noteTag,
  required String? accountTag,
}) => noteTag != null && accountTag != null && noteTag == accountTag;
