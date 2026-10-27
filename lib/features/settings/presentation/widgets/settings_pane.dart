import 'package:critalarm/design/design.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A page one of the Settings rows opens, in the order the rows run.
enum SettingsPage {
  sound('/sounds', opensInPane: true),
  priorities('/settings/priorities', opensInPane: true),
  storage('/settings/alarms', opensInPane: true),
  server('/settings/server', opensInPane: true),
  account('/settings/account'),
  personalize('/settings/personalize', opensInPane: true),
  appearance('/settings/appearance', opensInPane: true),
  language('/settings/language'),
  localReminders('/settings/local-reminders'),
  developer('/settings/developer'),
  privacy('/settings/privacy', opensInPane: true),
  about('/settings/about', opensInPane: true);

  const SettingsPage(this.path, {this.opensInPane = false});

  /// Where the page lives as a screen of its own.
  final String path;

  /// Whether the page can be drawn in the Settings detail pane. The others
  /// are owned by other features and always open as their own screen.
  final bool opensInPane;
}

/// The pages the Settings rows lead to on this phone, in row order. A
/// browser has no alarm and no local notifications, a self-hosted server has
/// no accounts, and only developer builds have the developer page.
List<SettingsPage> settingsPagesShown({
  required bool canRunAlarm,
  required bool hasAccounts,
  required bool hasLocalNotifications,
  required bool showsDeveloper,
}) => [
  for (final page in SettingsPage.values)
    if (switch (page) {
      SettingsPage.priorities => canRunAlarm,
      SettingsPage.account => hasAccounts,
      SettingsPage.localReminders => hasLocalNotifications,
      SettingsPage.developer => showsDeveloper,
      _ => true,
    })
      page,
];

/// The page the detail pane shows: [selected] while a row still shows it,
/// else the first page in [shown] that can be drawn in the pane. Null when
/// none can.
SettingsPage? settingsPaneSelection({
  required SettingsPage? selected,
  required List<SettingsPage> shown,
}) {
  if (selected != null && selected.opensInPane && shown.contains(selected)) {
    return selected;
  }
  for (final page in shown) {
    if (page.opensInPane) return page;
  }
  return null;
}

/// What a tap on a Settings row does.
enum SettingsRowTap {
  /// Show the page in the detail pane. Nothing is pushed and the URL stays.
  select,

  /// Push the page as a screen of its own.
  push,
}

/// [SettingsRowTap] for a row leading to [page], where [showsDetail] says
/// whether the display has a detail pane beside the list.
SettingsRowTap settingsRowTapFor({
  required bool showsDetail,
  required SettingsPage page,
}) => showsDetail && page.opensInPane
    ? SettingsRowTap.select
    : SettingsRowTap.push;

/// Marks a Settings page drawn in the detail pane beside the rows, so it
/// leaves out its back button: the rows beside it are the way to another
/// page, and there is nothing to go back to.
///
/// It also stops the page from tinting the canvas behind the whole window:
/// the pane is one part of the Settings screen, not a screen of its own.
class SettingsPaneScope extends StatelessWidget {
  const SettingsPaneScope({required this.child, super.key});

  final Widget child;

  /// Whether [context] is inside the Settings detail pane.
  static bool isIn(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SettingsPaneMarker>() != null;

  @override
  Widget build(BuildContext context) => _SettingsPaneMarker(
    // Active, so the page's scaffold stays see-through over the pane's
    // surface, but with no controller, so an override has nowhere to go.
    child: AmbientScope(child: child),
  );
}

class _SettingsPaneMarker extends InheritedWidget {
  const _SettingsPaneMarker({required super.child});

  @override
  bool updateShouldNotify(_SettingsPaneMarker oldWidget) => false;
}

/// The back button of a Settings page, or null inside the detail pane.
///
/// Pops when there is a page under this one, and otherwise goes to
/// [fallback], the way every Settings page did on its own.
Widget? settingsBackButton(
  BuildContext context, {
  String? ariaLabel,
  String fallback = '/settings',
}) {
  if (SettingsPaneScope.isIn(context)) return null;
  return AppIconButton(
    glyph: GlyphType.back,
    ariaLabel: ariaLabel ?? LocaleKeys.common_back.tr(),
    onPressed: () {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(fallback);
      }
    },
  );
}
