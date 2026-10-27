import 'package:critalarm/features/settings/presentation/widgets/settings_pane.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<SettingsPage> nativeShown() => settingsPagesShown(
    canRunAlarm: true,
    hasAccounts: true,
    hasLocalNotifications: true,
    showsDeveloper: false,
  );

  List<SettingsPage> webShown() => settingsPagesShown(
    canRunAlarm: false,
    hasAccounts: true,
    hasLocalNotifications: false,
    showsDeveloper: false,
  );

  group('settingsPagesShown', () {
    test('a phone lists every row but the developer page, in row order', () {
      expect(nativeShown(), [
        SettingsPage.sound,
        SettingsPage.priorities,
        SettingsPage.storage,
        SettingsPage.server,
        SettingsPage.account,
        SettingsPage.personalize,
        SettingsPage.appearance,
        SettingsPage.language,
        SettingsPage.localReminders,
        SettingsPage.privacy,
        SettingsPage.about,
      ]);
    });

    test('the web has no Priorities and no local reminders', () {
      final shown = webShown();
      expect(shown, isNot(contains(SettingsPage.priorities)));
      expect(shown, isNot(contains(SettingsPage.localReminders)));
      expect(shown.first, SettingsPage.sound);
    });

    test('a self-hosted server has no account row', () {
      final shown = settingsPagesShown(
        canRunAlarm: true,
        hasAccounts: false,
        hasLocalNotifications: true,
        showsDeveloper: true,
      );
      expect(shown, isNot(contains(SettingsPage.account)));
      expect(shown, contains(SettingsPage.developer));
    });
  });

  group('settingsPaneSelection', () {
    test('opens on the first row before anything is tapped', () {
      expect(
        settingsPaneSelection(selected: null, shown: nativeShown()),
        SettingsPage.sound,
      );
      expect(
        settingsPaneSelection(selected: null, shown: webShown()),
        SettingsPage.sound,
      );
    });

    test('keeps a tapped row that opens in the pane', () {
      expect(
        settingsPaneSelection(
          selected: SettingsPage.server,
          shown: nativeShown(),
        ),
        SettingsPage.server,
      );
    });

    test('falls back to the first row when the tapped row is gone', () {
      // Priorities is not listed on the web.
      expect(
        settingsPaneSelection(
          selected: SettingsPage.priorities,
          shown: webShown(),
        ),
        SettingsPage.sound,
      );
    });

    test('never selects a page that does not draw in the pane', () {
      expect(
        settingsPaneSelection(
          selected: SettingsPage.language,
          shown: nativeShown(),
        ),
        SettingsPage.sound,
      );
      expect(
        settingsPaneSelection(
          selected: null,
          shown: const [SettingsPage.account, SettingsPage.server],
        ),
        SettingsPage.server,
      );
      expect(
        settingsPaneSelection(
          selected: null,
          shown: const [SettingsPage.account, SettingsPage.language],
        ),
        isNull,
      );
    });
  });

  group('settingsRowTapFor', () {
    test('with a pane, a pane page is selected and nothing is pushed', () {
      for (final page in [
        SettingsPage.sound,
        SettingsPage.priorities,
        SettingsPage.storage,
        SettingsPage.server,
        SettingsPage.personalize,
        SettingsPage.appearance,
        SettingsPage.privacy,
        SettingsPage.about,
      ]) {
        expect(
          settingsRowTapFor(showsDetail: true, page: page),
          SettingsRowTap.select,
          reason: page.name,
        );
      }
    });

    test('with a pane, a page owned by another feature still pushes', () {
      for (final page in [
        SettingsPage.account,
        SettingsPage.language,
        SettingsPage.localReminders,
        SettingsPage.developer,
      ]) {
        expect(
          settingsRowTapFor(showsDetail: true, page: page),
          SettingsRowTap.push,
          reason: page.name,
        );
      }
    });

    test('without a pane every row pushes its page', () {
      for (final page in SettingsPage.values) {
        expect(
          settingsRowTapFor(showsDetail: false, page: page),
          SettingsRowTap.push,
          reason: page.name,
        );
      }
    });

    test('Server pushes its own route', () {
      expect(SettingsPage.server.path, '/settings/server');
      expect(SettingsPage.sound.path, '/sounds');
    });
  });
}
