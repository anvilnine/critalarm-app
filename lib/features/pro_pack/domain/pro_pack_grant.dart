import 'package:flutter/foundation.dart';

/// What the app knows about this install apart from the relay's `packs`
/// list. Handed to [proPackGrantedElsewhere] and used for nothing else.
@immutable
final class ProPackOtherSources {
  const ProPackOtherSources({this.tier});

  /// The tier the relay registered this device on, or null when unknown.
  final String? tier;

  @override
  bool operator ==(Object other) =>
      other is ProPackOtherSources && other.tier == tier;

  @override
  int get hashCode => tier.hashCode;
}

/// Answers whether something other than the relay's `packs` list grants the
/// Pro pack.
typedef ProPackOtherGrant = bool Function(ProPackOtherSources sources);

/// The one place a source other than the relay's `packs` list could grant
/// the Pro pack.
///
/// It grants nothing today, for every input. The app reads `packs` and never
/// works a pack out from the tier (api.md §4.2).
bool proPackGrantedElsewhere(ProPackOtherSources sources) => false;
