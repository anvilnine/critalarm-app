import 'package:flutter/foundation.dart';

/// One add-on an account holds beside its tier (api.md §4.2).
///
/// The relay lists the packs an account holds and says nothing about how one
/// was granted. A client reads the list and never works a pack out from the
/// tier.
@immutable
final class AccountPack {
  const AccountPack({required this.id, this.expiresAt});

  /// The pack's name on the wire.
  final String id;

  /// Epoch seconds, or null when the pack has no end date. Kept as the relay
  /// sent it. The list is what says a pack is held, not this field.
  final int? expiresAt;

  Map<String, dynamic> toJson() => {'id': id, 'expires_at': expiresAt};

  @override
  bool operator ==(Object other) =>
      other is AccountPack && other.id == id && other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(id, expiresAt);

  @override
  String toString() => 'AccountPack($id, expiresAt: $expiresAt)';
}

/// Reads a `packs` value off the wire or off disk.
///
/// Anything that is not a list reads as no packs, and an entry with no usable
/// `id` is dropped, so one odd entry never throws a whole registration away.
List<AccountPack> accountPacksFromJson(Object? json) {
  if (json is! List) return const [];
  return [
    for (final entry in json)
      if (entry is Map && entry['id'] is String && entry['id'] != '')
        AccountPack(
          id: entry['id'] as String,
          expiresAt: (entry['expires_at'] as num?)?.toInt(),
        ),
  ];
}

List<Map<String, dynamic>> accountPacksToJson(List<AccountPack> packs) => [
  for (final pack in packs) pack.toJson(),
];

/// `GET /relay/v1/packs`: what the relay holds, with no store call behind it.
@immutable
final class PacksAnswer {
  const PacksAnswer({required this.packs, this.checkedAt});

  factory PacksAnswer.fromJson(Map<String, dynamic> json) => PacksAnswer(
    packs: accountPacksFromJson(json['packs']),
    checkedAt: (json['checked_at'] as num?)?.toInt(),
  );

  final List<AccountPack> packs;

  /// The oldest successful store read, in epoch seconds, or null when there
  /// has been none.
  final int? checkedAt;
}

/// `POST /relay/v1/packs/refresh`: the relay read the store inside the call.
///
/// [confirmed] describes that read and nothing else. It is not a statement
/// about [packs].
@immutable
final class PacksRefreshAnswer {
  const PacksRefreshAnswer({
    required this.confirmed,
    required this.packs,
    this.checkedAt,
  });

  factory PacksRefreshAnswer.fromJson(Map<String, dynamic> json) =>
      PacksRefreshAnswer(
        // Only a literal true counts as a store read that worked.
        confirmed: json['confirmed'] == true,
        packs: accountPacksFromJson(json['packs']),
        checkedAt: (json['checked_at'] as num?)?.toInt(),
      );

  final bool confirmed;
  final List<AccountPack> packs;
  final int? checkedAt;
}
