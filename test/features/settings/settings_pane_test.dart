import 'package:critalarm/features/settings/presentation/widgets/settings_pane.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<SettingsPage> nativeShown() =>
      settingsPagesShown(hasLocalNotifications: true);

  List<SettingsPage> webShown() =>
      settingsPagesShown(hasLocalNotifications: false);

  group('settingsPagesShown', () {
    test('a phone lists every row, in the order of the cards', () {
      expect(nativeShown(), [
        SettingsPage.accountPlan,
        SettingsPage.ringing,
        SettingsPage.personalize,
        SettingsPage.appearance,
        SettingsPage.language,
        SettingsPage.localReminders,
        SettingsPage.server,
        SettingsPage.storage,
        SettingsPage.privacy,
        SettingsPage.help,
        SettingsPage.about,
      ]);
    });

    test('the web has no local reminders, and keeps Ringing for the sound', () {
      final shown = webShown();
      expect(shown, isNot(contains(SettingsPage.localReminders)));
      expect(shown, contains(SettingsPage.ringing));
      expect(shown.first, SettingsPage.accountPlan);
    });

    test('the pages one level down keep their old routes', () {
      expect(SettingsLinks.defaultSound, '/sounds');
      expect(SettingsLinks.priorities, '/settings/priorities');
      expect(SettingsLinks.developer, '/settings/developer');
      expect(SettingsLinks.deleteAccount, '/settings/account/delete');
      expect(SettingsPage.accountPlan.path, '/settings/account');
      expect(SettingsPage.storage.path, '/settings/alarms');
    });
  });

  group('settingsPaneSelection', () {
    test('opens on the first row before anything is tapped', () {
      expect(
        settingsPaneSelection(selected: null, shown: nativeShown()),
        SettingsPage.accountPlan,
      );
      expect(
        settingsPaneSelection(selected: null, shown: webShown()),
        SettingsPage.accountPlan,
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
      // Local reminders is not listed on the web.
      expect(
        settingsPaneSelection(
          selected: SettingsPage.localReminders,
          shown: webShown(),
        ),
        SettingsPage.accountPlan,
      );
    });

    test('never selects a page that does not draw in the pane', () {
      expect(
        settingsPaneSelection(
          selected: SettingsPage.language,
          shown: nativeShown(),
        ),
        SettingsPage.accountPlan,
      );
      expect(
        settingsPaneSelection(
          selected: null,
          shown: const [SettingsPage.language, SettingsPage.server],
        ),
        SettingsPage.server,
      );
      expect(
        settingsPaneSelection(
          selected: null,
          shown: const [SettingsPage.localReminders, SettingsPage.language],
        ),
        isNull,
      );
    });
  });

  group('settingsPaneOpening', () {
    test('draws no page while the connection is not read yet', () {
      for (final isConnected in [true, false]) {
        expect(
          settingsPaneOpening(
            selected: null,
            shown: nativeShown(),
            connectionKnown: false,
            isConnected: isConnected,
          ),
          isNull,
          reason: 'isConnected: $isConnected',
        );
      }
    });

    test('a tapped row shows while the connection is not read yet', () {
      expect(
        settingsPaneOpening(
          selected: SettingsPage.storage,
          shown: nativeShown(),
          connectionKnown: false,
          isConnected: false,
        ),
        SettingsPage.storage,
      );
      // A tapped row that never draws in the pane still waits.
      expect(
        settingsPaneOpening(
          selected: SettingsPage.language,
          shown: nativeShown(),
          connectionKnown: false,
          isConnected: false,
        ),
        isNull,
      );
    });

    test('the lost-server screen opens on Server from the first frame', () {
      expect(
        settingsPaneOpening(
          selected: null,
          shown: nativeShown(),
          connectionKnown: false,
          isConnected: false,
          forceDisconnected: true,
        ),
        SettingsPage.server,
      );
    });

    test('once read, a lost server opens on Server', () {
      expect(
        settingsPaneOpening(
          selected: null,
          shown: nativeShown(),
          connectionKnown: true,
          isConnected: false,
        ),
        SettingsPage.server,
      );
    });

    test('once read, a connected phone opens on the first row', () {
      expect(
        settingsPaneOpening(
          selected: null,
          shown: nativeShown(),
          connectionKnown: true,
          isConnected: true,
        ),
        SettingsPage.accountPlan,
      );
    });

    test('a tapped row wins over Server once read', () {
      expect(
        settingsPaneOpening(
          selected: SettingsPage.about,
          shown: nativeShown(),
          connectionKnown: true,
          isConnected: false,
        ),
        SettingsPage.about,
      );
    });
  });

  group('settingsPaneSelection with a preferred page', () {
    test('a phone that lost its server opens on Server', () {
      expect(
        settingsPaneSelection(
          selected: null,
          shown: nativeShown(),
          preferred: SettingsPage.server,
        ),
        SettingsPage.server,
      );
    });

    test('a tapped row wins over the preferred page', () {
      expect(
        settingsPaneSelection(
          selected: SettingsPage.appearance,
          shown: nativeShown(),
          preferred: SettingsPage.server,
        ),
        SettingsPage.appearance,
      );
    });

    test('a preferred page that is not listed or not in the pane is passed '
        'over for the first row', () {
      expect(
        settingsPaneSelection(
          selected: null,
          shown: webShown(),
          preferred: SettingsPage.localReminders,
        ),
        SettingsPage.accountPlan,
      );
      expect(
        settingsPaneSelection(
          selected: null,
          shown: nativeShown(),
          preferred: SettingsPage.language,
        ),
        SettingsPage.accountPlan,
      );
    });
  });

  group('settingsRowTapFor', () {
    test('with a pane, a pane page is selected and nothing is pushed', () {
      for (final page in [
        SettingsPage.accountPlan,
        SettingsPage.ringing,
        SettingsPage.storage,
        SettingsPage.server,
        SettingsPage.personalize,
        SettingsPage.appearance,
        SettingsPage.privacy,
        SettingsPage.help,
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
        SettingsPage.language,
        SettingsPage.localReminders,
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
      expect(SettingsPage.ringing.path, '/settings/ringing');
      expect(SettingsPage.help.path, '/settings/help');
    });
  });
}
