import 'package:critalarm/features/onboarding/domain/connect/connect_sheet_rules.dart';
import 'package:flutter_test/flutter_test.dart';

ConnectSheetSituation _now({
  bool setupDone = true,
  bool onConnectStep = false,
  bool alarmOn = false,
  bool sheetUp = false,
  bool blockedScreen = false,
}) => ConnectSheetSituation(
  blockedScreen: blockedScreen,
  setupDone: setupDone,
  onConnectStep: onConnectStep,
  alarmOn: alarmOn,
  sheetUp: sheetUp,
);

void main() {
  group('the connect sheet can show now', () {
    test('after setup, with nothing else up', () {
      expect(canShowConnectSheetNow(_now()), isTrue);
      expect(connectSheetBlock(_now()), isNull);
    });

    test('at the connect step while setup is not finished', () {
      expect(
        canShowConnectSheetNow(_now(setupDone: false, onConnectStep: true)),
        isTrue,
      );
    });

    test('not while setup is not finished and another step is up', () {
      final now = _now(setupDone: false);
      expect(canShowConnectSheetNow(now), isFalse);
      expect(connectSheetBlock(now), ConnectSheetBlock.setup);
    });

    test('not while an alarm has focus, even after setup', () {
      final now = _now(alarmOn: true);
      expect(canShowConnectSheetNow(now), isFalse);
      expect(connectSheetBlock(now), ConnectSheetBlock.alarm);
    });

    test('not while an alarm has focus, even at the connect step', () {
      final now = _now(
        setupDone: false,
        onConnectStep: true,
        alarmOn: true,
      );
      expect(connectSheetBlock(now), ConnectSheetBlock.alarm);
    });

    test('not while another sheet is up', () {
      final now = _now(sheetUp: true);
      expect(canShowConnectSheetNow(now), isFalse);
      expect(connectSheetBlock(now), ConnectSheetBlock.otherSheet);
    });

    test('not while another sheet is up at the connect step', () {
      final now = _now(
        setupDone: false,
        onConnectStep: true,
        sheetUp: true,
      );
      expect(connectSheetBlock(now), ConnectSheetBlock.otherSheet);
    });

    test('an alarm outranks setup, and setup outranks a sheet', () {
      expect(
        connectSheetBlock(
          _now(setupDone: false, alarmOn: true, sheetUp: true),
        ),
        ConnectSheetBlock.alarm,
      );
      expect(
        connectSheetBlock(_now(setupDone: false, sheetUp: true)),
        ConnectSheetBlock.setup,
      );
    });

    test('not on a screen that owns the display', () {
      final now = _now(blockedScreen: true);
      expect(canShowConnectSheetNow(now), isFalse);
      expect(connectSheetBlock(now), ConnectSheetBlock.screen);
      // Not even at the connect step.
      expect(
        connectSheetBlock(
          _now(setupDone: false, onConnectStep: true, blockedScreen: true),
        ),
        ConnectSheetBlock.screen,
      );
    });

    test('an alarm outranks a blocked screen', () {
      expect(
        connectSheetBlock(_now(alarmOn: true, blockedScreen: true)),
        ConnectSheetBlock.alarm,
      );
    });

    test('every combination answers, and only the open ones show', () {
      for (final setupDone in [true, false]) {
        for (final onConnectStep in [true, false]) {
          for (final alarmOn in [true, false]) {
            for (final sheetUp in [true, false]) {
              final open = !alarmOn && !sheetUp && (setupDone || onConnectStep);
              expect(
                canShowConnectSheetNow(
                  _now(
                    setupDone: setupDone,
                    onConnectStep: onConnectStep,
                    alarmOn: alarmOn,
                    sheetUp: sheetUp,
                  ),
                ),
                open,
                reason:
                    'setupDone=$setupDone onConnectStep=$onConnectStep '
                    'alarmOn=$alarmOn sheetUp=$sheetUp',
              );
            }
          }
        }
      }
    });
  });

  group('screens the sheet never opens over', () {
    test('the paywall, the purchase screen, the alarm, the ringing screens '
        'and the lock screen', () {
      for (final path in [
        '/paywall',
        '/paywall/success',
        '/plans/hero',
        '/plans/sheet',
        '/alarm',
        '/incidents/inc_9a8b7c',
        '/ring',
        '/lockscreen',
      ]) {
        expect(isConnectSheetBlockedPath(path), isTrue, reason: path);
      }
    });

    test('Home, Settings, setup and the topic screens are fine', () {
      for (final path in [
        '/',
        '/history',
        '/settings',
        '/settings/server',
        '/settings/reliability',
        '/onboarding/connect',
        '/topics/prod',
        '/paywallish',
        '/plans',
        '/incidents',
      ]) {
        expect(isConnectSheetBlockedPath(path), isFalse, reason: path);
      }
    });
  });
}
