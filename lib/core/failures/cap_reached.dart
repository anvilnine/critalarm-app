import 'package:critalarm/core/failures/failure.dart';
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

  String get label => switch (name) {
    'critical_topics' => 'Critical topics',
    'devices' => 'Devices',
    'p4_daily' => 'Daily high-priority pushes',
    _ => name,
  };
  String get message => '$label limit reached';
  @override
  bool operator ==(Object other) => other is CapReached && other.name == name;
  @override
  int get hashCode => name.hashCode;
}
