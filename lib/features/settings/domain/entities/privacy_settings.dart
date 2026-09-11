import 'package:flutter/foundation.dart';

/// User privacy choices for anonymous analytics and crash reports.
@immutable
class PrivacySettings {
  const PrivacySettings({
    this.analyticsEnabled = false,
    this.crashReportingEnabled = false,
  });

  final bool analyticsEnabled;
  final bool crashReportingEnabled;

  PrivacySettings copyWith({
    bool? analyticsEnabled,
    bool? crashReportingEnabled,
  }) {
    return PrivacySettings(
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      crashReportingEnabled:
          crashReportingEnabled ?? this.crashReportingEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacySettings &&
          runtimeType == other.runtimeType &&
          analyticsEnabled == other.analyticsEnabled &&
          crashReportingEnabled == other.crashReportingEnabled;

  @override
  int get hashCode => Object.hash(analyticsEnabled, crashReportingEnabled);
}
