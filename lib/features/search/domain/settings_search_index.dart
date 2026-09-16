import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/foundation.dart';

/// One thing under Settings that search can take the user to.
///
/// Holds translation keys, not translated text, so this list stays free of
/// Flutter and easy_localization. The cubit translates when it builds results.
@immutable
class SettingsDestination {
  const SettingsDestination({
    required this.id,
    required this.routePath,
    required this.titleKey,
    required this.parentTitleKey,
    this.keywords = const <String>[],
    this.devOnly = false,
  });

  final String id;

  /// Where tapping goes. Several rows share a screen, which is fine: search
  /// gets the user to the right page, and the row is in front of them there.
  final String routePath;

  final String titleKey;

  /// The screen this lives on, drawn as the grey line under the title.
  final String parentTitleKey;

  /// Plain words a user might type instead of the row's own wording.
  /// Lowercase. Never shown.
  final List<String> keywords;

  /// Only in a build that skips the paywall, matching the Settings screen.
  final bool devOnly;
}

/// Everything under Settings that search can reach.
///
/// Add a row here when you add a row to a settings screen. Nothing generates
/// this, so a new setting is unsearchable until it is listed.
abstract final class SettingsSearchIndex {
  static const List<SettingsDestination> all = <SettingsDestination>[
    // The six top level screens.
    SettingsDestination(
      id: 'health',
      routePath: '/settings/permissions',
      titleKey: LocaleKeys.settings_health_row_title,
      parentTitleKey: LocaleKeys.nav_settings,
      keywords: <String>[
        'permissions',
        'notifications',
        'battery',
        'critical alerts',
        'health',
      ],
    ),
    SettingsDestination(
      id: 'alarms',
      routePath: '/settings/alarms',
      titleKey: LocaleKeys.settings_alarms_row_title,
      parentTitleKey: LocaleKeys.nav_settings,
      keywords: <String>['alarm', 'ring', 'sound', 'volume'],
    ),
    SettingsDestination(
      id: 'server',
      routePath: '/settings/server',
      titleKey: LocaleKeys.settings_server_row_title,
      parentTitleKey: LocaleKeys.nav_settings,
      keywords: <String>[
        'server',
        'connection',
        'url',
        'token',
        'disconnect',
        'self hosted',
      ],
    ),
    SettingsDestination(
      id: 'privacy',
      routePath: '/settings/privacy',
      titleKey: LocaleKeys.settings_privacy_row_title,
      parentTitleKey: LocaleKeys.nav_settings,
      keywords: <String>['privacy', 'analytics', 'crash', 'telemetry', 'data'],
    ),
    SettingsDestination(
      id: 'about',
      routePath: '/settings/about',
      titleKey: LocaleKeys.settings_about_row_title,
      parentTitleKey: LocaleKeys.nav_settings,
      keywords: <String>['about', 'version', 'licence', 'license', 'github'],
    ),
    SettingsDestination(
      id: 'developer',
      routePath: '/settings/developer',
      titleKey: LocaleKeys.settings_developer_row_title,
      parentTitleKey: LocaleKeys.nav_settings,
      keywords: <String>['developer', 'debug'],
      devOnly: true,
    ),

    // Rows that live inside one of those screens.
    SettingsDestination(
      id: 'alarm_sound',
      routePath: '/sounds',
      titleKey: LocaleKeys.settings_alarm_sound_row_title,
      parentTitleKey: LocaleKeys.settings_alarms_header,
      keywords: <String>['sound', 'ringtone', 'tone', 'siren', 'noise'],
    ),
    SettingsDestination(
      id: 'quiet_hours',
      routePath: '/settings/alarms',
      titleKey: LocaleKeys.settings_quiet_hours_label,
      parentTitleKey: LocaleKeys.settings_alarms_header,
      keywords: <String>[
        'quiet',
        'do not disturb',
        'night',
        'schedule',
        'silence',
      ],
    ),
    SettingsDestination(
      id: 'critical_rings',
      routePath: '/settings/alarms',
      titleKey: LocaleKeys.settings_critical_rings_title,
      parentTitleKey: LocaleKeys.settings_alarms_header,
      keywords: <String>['critical', 'override', 'silent', 'loud'],
    ),
    SettingsDestination(
      id: 'escalation_call',
      routePath: '/settings/alarms',
      titleKey: LocaleKeys.settings_escalation_call_title,
      parentTitleKey: LocaleKeys.settings_alarms_header,
      keywords: <String>['escalate', 'escalation', 'phone call', 'backup'],
    ),
    SettingsDestination(
      id: 'analytics',
      routePath: '/settings/privacy',
      titleKey: LocaleKeys.settings_analytics_title,
      parentTitleKey: LocaleKeys.settings_privacy_header,
      keywords: <String>['analytics', 'usage', 'tracking', 'opt out'],
    ),
    SettingsDestination(
      id: 'crash_reports',
      routePath: '/settings/privacy',
      titleKey: LocaleKeys.settings_crash_reports_title,
      parentTitleKey: LocaleKeys.settings_privacy_header,
      keywords: <String>['crash', 'bug', 'reporting', 'diagnostics'],
    ),
    SettingsDestination(
      id: 'theme',
      routePath: '/settings',
      titleKey: LocaleKeys.settings_theme_header,
      parentTitleKey: LocaleKeys.nav_settings,
      keywords: <String>[
        'theme',
        'dark',
        'light',
        'dark mode',
        'appearance',
        'colour',
        'color',
      ],
    ),
    SettingsDestination(
      id: 'plan',
      routePath: '/paywall',
      titleKey: LocaleKeys.settings_plan_header,
      parentTitleKey: LocaleKeys.nav_settings,
      keywords: <String>[
        'plan',
        'pro',
        'free',
        'upgrade',
        'subscription',
        'billing',
        'pay',
      ],
    ),
    SettingsDestination(
      id: 'version',
      routePath: '/settings/about',
      titleKey: LocaleKeys.settings_about_version_label,
      parentTitleKey: LocaleKeys.settings_about_header,
      keywords: <String>['version', 'build number'],
    ),
    SettingsDestination(
      id: 'licence',
      routePath: '/settings/about',
      titleKey: LocaleKeys.settings_about_license_label,
      parentTitleKey: LocaleKeys.settings_about_header,
      keywords: <String>['licence', 'license', 'gpl', 'open source'],
    ),
    SettingsDestination(
      id: 'docs_link',
      routePath: '/settings/about',
      titleKey: LocaleKeys.settings_about_docs_label,
      parentTitleKey: LocaleKeys.settings_about_header,
      keywords: <String>['docs', 'documentation', 'help', 'guide', 'manual'],
    ),
    SettingsDestination(
      id: 'github',
      routePath: '/settings/about',
      titleKey: LocaleKeys.settings_about_github_label,
      parentTitleKey: LocaleKeys.settings_about_header,
      keywords: <String>['github', 'source', 'code', 'repo'],
    ),
    SettingsDestination(
      id: 'issues',
      routePath: '/settings/about',
      titleKey: LocaleKeys.settings_about_issues_label,
      parentTitleKey: LocaleKeys.settings_about_header,
      keywords: <String>['issue', 'bug report', 'feedback', 'support'],
    ),
    SettingsDestination(
      id: 'developer_pro',
      routePath: '/settings/developer',
      titleKey: LocaleKeys.settings_developer_pro_title,
      parentTitleKey: LocaleKeys.settings_developer_header,
      keywords: <String>['pro toggle', 'fake subscription', 'debug'],
      devOnly: true,
    ),
  ];

  /// The rows a given build should search. A release build never offers the
  /// developer screen, so it must never find it either.
  static List<SettingsDestination> forBuild({required bool includeDevOnly}) {
    if (includeDevOnly) return all;
    return <SettingsDestination>[
      for (final destination in all)
        if (!destination.devOnly) destination,
    ];
  }
}
