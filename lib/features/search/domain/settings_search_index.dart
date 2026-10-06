import 'package:critalarm/core/paywall/paywall_source.dart';
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
    this.needsStorageSection = false,
    this.hiddenWhenSelfHosted = false,
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

  /// Lives in the Storage section, which Settings only draws on a paid plan
  /// or a self-hosted server. Search must not find a row that is not there.
  final bool needsStorageSection;

  /// Leads to a plan or a purchase. A self-hosted server has no plans, so
  /// Settings does not draw the row and search must not find it.
  final bool hiddenWhenSelfHosted;
}

/// Everything under Settings that search can reach.
///
/// Add a row here when you add a row to a settings screen. Nothing generates
/// this, so a new setting is unsearchable until it is listed.
abstract final class SettingsSearchIndex {
  static final List<SettingsDestination> all = <SettingsDestination>[
    // The six top level screens.
    const SettingsDestination(
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
    const SettingsDestination(
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
    const SettingsDestination(
      id: 'privacy',
      routePath: '/settings/privacy',
      titleKey: LocaleKeys.settings_privacy_row_title,
      parentTitleKey: LocaleKeys.nav_settings,
      keywords: <String>['privacy', 'analytics', 'crash', 'telemetry', 'data'],
    ),
    const SettingsDestination(
      id: 'about',
      routePath: '/settings/about',
      titleKey: LocaleKeys.settings_about_row_title,
      parentTitleKey: LocaleKeys.nav_settings,
      keywords: <String>['about', 'version', 'licence', 'license', 'github'],
    ),
    const SettingsDestination(
      id: 'developer',
      routePath: '/settings/developer',
      titleKey: LocaleKeys.settings_developer_row_title,
      parentTitleKey: LocaleKeys.nav_settings,
      keywords: <String>['developer', 'debug'],
      devOnly: true,
    ),

    // Rows that live inside one of those screens.
    const SettingsDestination(
      id: 'alarm_sound',
      routePath: '/sounds',
      titleKey: LocaleKeys.settings_alarm_sound_row_title,
      parentTitleKey: LocaleKeys.nav_settings,
      keywords: <String>[
        'sound',
        'ringtone',
        'tone',
        'siren',
        'noise',
        'record',
        'voice memo',
        'alarm',
        'ring',
        'volume',
        // The built-in emergency sounds.
        'emergency',
        'klaxon',
        'sos',
        'beeper',
        'horn',
        'bell',
      ],
    ),
    // 'quiet_hours', 'critical_rings' and 'escalation_call' are out while
    // their rows are off the alarm settings screen. Searching for them would
    // land on a screen that no longer shows them.
    const SettingsDestination(
      id: 'analytics',
      routePath: '/settings/privacy',
      titleKey: LocaleKeys.settings_analytics_title,
      parentTitleKey: LocaleKeys.settings_privacy_header,
      keywords: <String>['analytics', 'usage', 'tracking', 'opt out'],
    ),
    const SettingsDestination(
      id: 'crash_reports',
      routePath: '/settings/privacy',
      titleKey: LocaleKeys.settings_crash_reports_title,
      parentTitleKey: LocaleKeys.settings_privacy_header,
      keywords: <String>['crash', 'bug', 'reporting', 'diagnostics'],
    ),
    const SettingsDestination(
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
    const SettingsDestination(
      id: 'app-icon',
      routePath: '/settings/appearance',
      titleKey: LocaleKeys.settings_app_icon_row_title,
      parentTitleKey: LocaleKeys.settings_appearance_header,
      keywords: <String>[
        'icon',
        'app icon',
        'home screen',
        'crown',
        'shades',
        'hosted',
      ],
    ),
    const SettingsDestination(
      id: 'storage-delete-after',
      routePath: '/settings/alarms',
      titleKey: LocaleKeys.settings_storage_delete_after_title,
      parentTitleKey: LocaleKeys.settings_storage_header,
      keywords: <String>[
        'storage',
        'delete',
        'auto delete',
        'keep',
        'history',
        'space',
      ],
      needsStorageSection: true,
    ),
    const SettingsDestination(
      id: 'storage-keep-critical',
      routePath: '/settings/alarms',
      titleKey: LocaleKeys.settings_storage_keep_critical_title,
      parentTitleKey: LocaleKeys.settings_storage_header,
      keywords: <String>[
        'critical',
        'priority 5',
        'p5',
        'keep forever',
        'storage',
      ],
      needsStorageSection: true,
    ),
    SettingsDestination(
      id: 'plan',
      routePath: paywallLocation(PaywallSource.settingsSearch),
      titleKey: LocaleKeys.settings_plan_header,
      parentTitleKey: LocaleKeys.nav_settings,
      keywords: const <String>[
        'plan',
        'hosted',
        'free',
        'upgrade',
        'subscription',
        'billing',
        'pay',
      ],
      hiddenWhenSelfHosted: true,
    ),
    const SettingsDestination(
      id: 'version',
      routePath: '/settings/about',
      titleKey: LocaleKeys.settings_about_version_label,
      parentTitleKey: LocaleKeys.settings_about_header,
      keywords: <String>['version', 'build number'],
    ),
    const SettingsDestination(
      id: 'licence',
      routePath: '/settings/about',
      titleKey: LocaleKeys.settings_about_license_label,
      parentTitleKey: LocaleKeys.settings_about_header,
      keywords: <String>['licence', 'license', 'gpl', 'open source'],
    ),
    const SettingsDestination(
      id: 'docs_link',
      routePath: '/settings/about',
      titleKey: LocaleKeys.settings_about_docs_label,
      parentTitleKey: LocaleKeys.settings_about_header,
      keywords: <String>['docs', 'documentation', 'help', 'guide', 'manual'],
    ),
    const SettingsDestination(
      id: 'github',
      routePath: '/settings/about',
      titleKey: LocaleKeys.settings_about_github_label,
      parentTitleKey: LocaleKeys.settings_about_header,
      keywords: <String>['github', 'source', 'code', 'repo'],
    ),
    const SettingsDestination(
      id: 'issues',
      routePath: '/settings/about',
      titleKey: LocaleKeys.settings_about_issues_label,
      parentTitleKey: LocaleKeys.settings_about_header,
      keywords: <String>['issue', 'bug report', 'feedback', 'support'],
    ),
    const SettingsDestination(
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
  ///
  /// [showsStorage] matches `SettingsState.hasStorageSection`: true on a paid
  /// plan or a self-hosted server. Without it the Storage rows are left out.
  /// [isSelfHosted] leaves out the rows that lead to a plan.
  static List<SettingsDestination> forBuild({
    required bool includeDevOnly,
    required bool showsStorage,
    bool isSelfHosted = false,
  }) {
    return <SettingsDestination>[
      for (final destination in all)
        if ((includeDevOnly || !destination.devOnly) &&
            (showsStorage || !destination.needsStorageSection) &&
            !(isSelfHosted && destination.hiddenWhenSelfHosted))
          destination,
    ];
  }
}
