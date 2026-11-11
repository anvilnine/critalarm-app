import 'package:critalarm/design/design.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A page one of the Settings rows opens, in the order the rows run.
///
/// The account and plan card on top opens [accountPlan]. Then come the
/// titled cards: Alarms, App, Server and data, Help. Default sound and
/// Priorities sit on [ringing], Feature Guides on [help] and Developer
/// options on [about], one level down.
enum SettingsPage {
  accountPlan('/settings/account', opensInPane: true),
  ringing('/settings/ringing', opensInPane: true),
  personalize('/settings/personalize', opensInPane: true),
  appearance('/settings/appearance', opensInPane: true),
  language('/settings/language'),
  localReminders('/settings/local-reminders'),
  server('/settings/server', opensInPane: true),
  storage('/settings/alarms', opensInPane: true),
  privacy('/settings/privacy', opensInPane: true),
  help('/settings/help', opensInPane: true),
  about('/settings/about', opensInPane: true);

  const SettingsPage(this.path, {this.opensInPane = false});

  /// Where the page lives as a screen of its own.
  final String path;

  /// Whether the page can be drawn in the Settings detail pane. The others
  /// are owned by other features and always open as their own screen.
  final bool opensInPane;
}

/// Pages one level under a Settings page. Each one keeps the route it had
/// when it was a row of its own, so links and search still land on it.
abstract final class SettingsLinks {
  /// The Sound pass in Personalize, the one home of the default sound.
  static const String defaultSound = '/sounds';

  /// What each priority does. On Ringing.
  static const String priorities = '/settings/priorities';

  /// Developer options. On About, in developer builds only.
  static const String developer = '/settings/developer';

  /// The join code. On Account and plan.
  static const String joinCode = '/settings/account/join-code';

  /// Delete account and its confirm. At the bottom of Account and plan.
  static const String deleteAccount = '/settings/account/delete';
}

/// The pages the Settings rows lead to on this phone, in row order. A
/// browser has no local notifications, so no Local reminders row. Every
/// other page has a row everywhere: Ringing keeps the default sound on the
/// web, and Account and plan keeps the plan on a server of one's own.
List<SettingsPage> settingsPagesShown({
  required bool hasLocalNotifications,
}) => [
  for (final page in SettingsPage.values)
    if (switch (page) {
      SettingsPage.localReminders => hasLocalNotifications,
      _ => true,
    })
      page,
];

/// The page the detail pane shows: [selected] while a row still shows it,
/// else [preferred] when its row shows and it draws in the pane, else the
/// first page in [shown] that can be drawn in the pane. Null when none can.
///
/// [preferred] is the page the screen's state points at, such as Server on
/// a phone that lost its server.
SettingsPage? settingsPaneSelection({
  required SettingsPage? selected,
  required List<SettingsPage> shown,
  SettingsPage? preferred,
}) {
  bool fits(SettingsPage? page) =>
      page != null && page.opensInPane && shown.contains(page);
  if (fits(selected)) return selected;
  if (fits(preferred)) return preferred;
  for (final page in shown) {
    if (page.opensInPane) return page;
  }
  return null;
}

/// The page the Settings detail pane shows, from what the screen knows about
/// the connection. A phone that lost its server opens on Server.
///
/// Until a row is tapped, the pane waits for the saved connection to be read
/// ([connectionKnown]) and returns null, so it never draws the first row's
/// page and then swaps it for Server a moment later. [forceDisconnected] is
/// the lost-server screen, which knows the answer from its first frame and
/// does not wait.
SettingsPage? settingsPaneOpening({
  required SettingsPage? selected,
  required List<SettingsPage> shown,
  required bool connectionKnown,
  required bool isConnected,
  bool forceDisconnected = false,
}) {
  if (!forceDisconnected && !connectionKnown) {
    final tapped =
        selected != null && selected.opensInPane && shown.contains(selected);
    return tapped ? selected : null;
  }
  return settingsPaneSelection(
    selected: selected,
    shown: shown,
    preferred: forceDisconnected || !isConnected ? SettingsPage.server : null,
  );
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
