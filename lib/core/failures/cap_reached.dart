import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

/// Retains the server's cap name for the cap-reached presentation state.
@immutable
class CapReached {
  const CapReached(this.name);
  final String name;
  static CapReached? fromFailure(Failure failure) =>
      failure is ApiFailure && failure.statusCode == 429 && failure.cap != null
      ? CapReached(failure.cap!)
      : null;

  /// A cap name we have no wording for falls back to a generic label, never
  /// to the wire name. The error card puts this in its title.
  String get label => switch (name) {
    'critical_topics' => 'Critical topics',
    'devices' => 'Devices',
    'p4_daily' => 'Daily high-priority pushes',
    _ => LocaleKeys.account_cap_generic_label.tr(),
  };
  String get message => '$label limit reached';
  @override
  bool operator ==(Object other) => other is CapReached && other.name == name;
  @override
  int get hashCode => name.hashCode;
}
