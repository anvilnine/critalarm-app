import 'package:critalarm/core/device/device_maker.dart';
import 'package:critalarm/features/permissions/domain/entities/permission_setup_step.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const _samsung = DeviceMaker(manufacturer: 'samsung', brand: 'samsung');
const _pixel = DeviceMaker(manufacturer: 'Google', brand: 'google');

List<PermissionSetupStep> _steps(
  TargetPlatform platform, {
  bool isWeb = false,
  bool hasAlarmKit = false,
  DeviceMaker maker = DeviceMaker.unknown,
}) => permissionSetupStepsFor(
  platform,
  isWeb: isWeb,
  hasAlarmKit: hasAlarmKit,
  maker: maker,
);

void main() {
  group('the setup steps a phone gets', () {
    test('iOS with AlarmKit: notifications, then alarms', () {
      expect(_steps(TargetPlatform.iOS, hasAlarmKit: true), const [
        PermissionSetupStep.iosNotifications,
        PermissionSetupStep.iosAlarms,
      ]);
    });

    test('iOS without AlarmKit: notifications, then the explainer', () {
      expect(_steps(TargetPlatform.iOS), const [
        PermissionSetupStep.iosNotifications,
        PermissionSetupStep.iosTimeSensitiveExplainer,
      ]);
    });

    test('iOS never gets a battery step, whatever the maker says', () {
      for (final hasAlarmKit in [true, false]) {
        expect(
          _steps(
            TargetPlatform.iOS,
            hasAlarmKit: hasAlarmKit,
            maker: _samsung,
          ),
          isNot(contains(PermissionSetupStep.androidBattery)),
        );
      }
    });

    test('Android on a listed maker: battery comes third', () {
      expect(_steps(TargetPlatform.android, maker: _samsung), const [
        PermissionSetupStep.androidNotifications,
        PermissionSetupStep.androidFullScreen,
        PermissionSetupStep.androidBattery,
      ]);
    });

    test('Android on a Pixel: two steps, no battery', () {
      expect(_steps(TargetPlatform.android, maker: _pixel), const [
        PermissionSetupStep.androidNotifications,
        PermissionSetupStep.androidFullScreen,
      ]);
    });

    test('Android with an unknown maker: no battery', () {
      expect(_steps(TargetPlatform.android), const [
        PermissionSetupStep.androidNotifications,
        PermissionSetupStep.androidFullScreen,
      ]);
    });

    test('Android ignores AlarmKit', () {
      expect(
        _steps(TargetPlatform.android, hasAlarmKit: true, maker: _pixel),
        const [
          PermissionSetupStep.androidNotifications,
          PermissionSetupStep.androidFullScreen,
        ],
      );
    });

    test('web: none, whatever the platform underneath', () {
      for (final platform in TargetPlatform.values) {
        expect(
          _steps(platform, isWeb: true, hasAlarmKit: true, maker: _samsung),
          isEmpty,
        );
      }
    });

    test('desktop: none', () {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.windows,
        TargetPlatform.fuchsia,
      ]) {
        expect(_steps(platform, hasAlarmKit: true, maker: _samsung), isEmpty);
      }
    });

    test('no list mixes the two platforms', () {
      const ios = {
        PermissionSetupStep.iosNotifications,
        PermissionSetupStep.iosAlarms,
        PermissionSetupStep.iosTimeSensitiveExplainer,
      };
      for (final hasAlarmKit in [true, false]) {
        expect(
          _steps(
            TargetPlatform.iOS,
            hasAlarmKit: hasAlarmKit,
          ).toSet().difference(
            ios,
          ),
          isEmpty,
        );
        expect(
          _steps(
            TargetPlatform.android,
            hasAlarmKit: hasAlarmKit,
            maker: _samsung,
          ).toSet().intersection(ios),
          isEmpty,
        );
      }
    });
  });

  group('every permission granted', () {
    const android = [
      PermissionSetupStep.androidNotifications,
      PermissionSetupStep.androidFullScreen,
      PermissionSetupStep.androidBattery,
    ];

    test('needs every step that has a permission', () {
      expect(
        everySetupPermissionGranted(android, android.toSet()),
        isTrue,
      );
      for (final missing in android) {
        expect(
          everySetupPermissionGranted(android, {...android}..remove(missing)),
          isFalse,
          reason: '$missing is not granted',
        );
      }
    });

    test('the explainer has nothing to grant', () {
      expect(
        everySetupPermissionGranted(
          const [
            PermissionSetupStep.iosNotifications,
            PermissionSetupStep.iosTimeSensitiveExplainer,
          ],
          const {PermissionSetupStep.iosNotifications},
        ),
        isTrue,
      );
    });

    test('an empty list is granted', () {
      expect(everySetupPermissionGranted(const [], const {}), isTrue);
    });
  });

  group('the steps one run of the screen draws', () {
    const ios26 = [
      PermissionSetupStep.iosNotifications,
      PermissionSetupStep.iosAlarms,
    ];
    const iosOld = [
      PermissionSetupStep.iosNotifications,
      PermissionSetupStep.iosTimeSensitiveExplainer,
    ];
    const android = [
      PermissionSetupStep.androidNotifications,
      PermissionSetupStep.androidFullScreen,
      PermissionSetupStep.androidBattery,
    ];

    test('setup: a granted step is left out', () {
      expect(
        permissionStepsToRender(
          android,
          granted: const {PermissionSetupStep.androidFullScreen},
        ),
        const [
          PermissionSetupStep.androidNotifications,
          PermissionSetupStep.androidBattery,
        ],
      );
    });

    test('setup: everything granted draws nothing', () {
      expect(
        permissionStepsToRender(android, granted: android.toSet()),
        isEmpty,
      );
      expect(permissionStepsToRender(ios26, granted: ios26.toSet()), isEmpty);
    });

    test('setup: the explainer waits for notifications to be granted', () {
      expect(permissionStepsToRender(iosOld, granted: const {}), const [
        PermissionSetupStep.iosNotifications,
      ]);
    });

    test('setup: the explainer is left out after a refusal or a skip', () {
      expect(
        permissionStepsToRender(
          iosOld,
          granted: const {},
          alreadyShown: const {PermissionSetupStep.iosNotifications},
        ),
        const [PermissionSetupStep.iosNotifications],
      );
    });

    test('setup: the explainer never shows on its own', () {
      expect(
        permissionStepsToRender(
          iosOld,
          granted: const {PermissionSetupStep.iosNotifications},
        ),
        isEmpty,
      );
    });

    test('setup: a step already shown stays, granted or not', () {
      expect(
        permissionStepsToRender(
          iosOld,
          granted: const {PermissionSetupStep.iosNotifications},
          alreadyShown: const {PermissionSetupStep.iosNotifications},
        ),
        iosOld,
      );
      expect(
        permissionStepsToRender(
          android,
          granted: android.toSet(),
          alreadyShown: const {
            PermissionSetupStep.androidNotifications,
            PermissionSetupStep.androidFullScreen,
          },
        ),
        const [
          PermissionSetupStep.androidNotifications,
          PermissionSetupStep.androidFullScreen,
        ],
      );
    });

    test('replay: every step, whatever is granted', () {
      for (final list in [ios26, iosOld, android]) {
        expect(
          permissionStepsToRender(
            list,
            granted: list.toSet(),
            mode: PermissionAskMode.replay,
          ),
          list,
        );
      }
    });

    test('standalone: only steps with a prompt behind them', () {
      expect(
        permissionStepsToRender(
          iosOld,
          granted: const {},
          mode: PermissionAskMode.standalone,
        ),
        const [PermissionSetupStep.iosNotifications],
      );
      // Health has its own battery row, which explains before it asks.
      expect(
        permissionStepsToRender(
          android,
          granted: const {},
          mode: PermissionAskMode.standalone,
        ),
        const [
          PermissionSetupStep.androidNotifications,
          PermissionSetupStep.androidFullScreen,
        ],
      );
    });

    test('standalone: a prompt that is spent is not a step', () {
      expect(
        permissionStepsToRender(
          ios26,
          granted: const {},
          mode: PermissionAskMode.standalone,
          cannotAsk: const {PermissionSetupStep.iosAlarms},
        ),
        const [PermissionSetupStep.iosNotifications],
      );
    });

    test('setup: a spent prompt still shows, and moves on when tapped', () {
      expect(
        permissionStepsToRender(
          ios26,
          granted: const {},
          cannotAsk: const {PermissionSetupStep.iosAlarms},
        ),
        ios26,
      );
    });
  });

  group('the first step that still needs an answer', () {
    const android = [
      PermissionSetupStep.androidNotifications,
      PermissionSetupStep.androidFullScreen,
      PermissionSetupStep.androidBattery,
    ];

    test('is the first one drawn when nothing was shown yet', () {
      expect(
        nextPermissionStep(android, alreadyShown: const {}),
        PermissionSetupStep.androidNotifications,
      );
      expect(
        nextPermissionStep(const [
          PermissionSetupStep.androidBattery,
        ], alreadyShown: const {}),
        PermissionSetupStep.androidBattery,
      );
    });

    test('never goes back to one that was shown', () {
      expect(
        nextPermissionStep(
          android,
          alreadyShown: const {
            PermissionSetupStep.androidNotifications,
            PermissionSetupStep.androidFullScreen,
          },
        ),
        PermissionSetupStep.androidBattery,
      );
    });

    test('passes over a step that was granted since', () {
      expect(
        nextPermissionStep(
          android,
          alreadyShown: const {PermissionSetupStep.androidNotifications},
          granted: const {PermissionSetupStep.androidFullScreen},
        ),
        PermissionSetupStep.androidBattery,
      );
    });

    test('never goes back to an earlier step that was revoked', () {
      expect(
        nextPermissionStep(
          android,
          alreadyShown: const {
            PermissionSetupStep.androidNotifications,
            PermissionSetupStep.androidFullScreen,
          },
          granted: const {PermissionSetupStep.androidBattery},
        ),
        isNull,
      );
    });

    test('a replay shows a granted step like any other', () {
      expect(
        nextPermissionStep(
          android,
          alreadyShown: const {PermissionSetupStep.androidNotifications},
          granted: android.toSet(),
          showGranted: true,
        ),
        PermissionSetupStep.androidFullScreen,
      );
    });

    test('is null once every step was shown, or there is none', () {
      expect(
        nextPermissionStep(android, alreadyShown: android.toSet()),
        isNull,
      );
      expect(nextPermissionStep(const [], alreadyShown: const {}), isNull);
    });
  });

  group('the list on screen holds still', () {
    const android = [
      PermissionSetupStep.androidNotifications,
      PermissionSetupStep.androidFullScreen,
      PermissionSetupStep.androidBattery,
    ];

    test('the first list is taken as it is', () {
      expect(
        freezePermissionSteps(const [], android, order: android),
        android,
      );
    });

    test('a step granted since is not taken out', () {
      expect(
        freezePermissionSteps(android, const [
          PermissionSetupStep.androidNotifications,
          PermissionSetupStep.androidBattery,
        ], order: android),
        android,
      );
    });

    test('a step is never put in before the last one drawn', () {
      expect(
        freezePermissionSteps(
          const [PermissionSetupStep.androidBattery],
          android,
          order: android,
        ),
        const [PermissionSetupStep.androidBattery],
      );
    });

    test('a later step is appended', () {
      expect(
        freezePermissionSteps(
          const [PermissionSetupStep.androidNotifications],
          android,
          order: android,
        ),
        android,
      );
    });
  });

  group('whether the notification prompt is spent', () {
    bool spent(
      TargetPlatform platform, {
      bool granted = false,
      bool refusedBefore = false,
      int? sdk,
    }) => notificationPromptSpent(
      platform: platform,
      granted: granted,
      refusedBefore: refusedBefore,
      androidSdk: sdk,
    );

    test('never while granted', () {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        expect(
          spent(platform, granted: true, refusedBefore: true, sdk: 30),
          isFalse,
        );
      }
    });

    test('iOS: only after a refusal', () {
      expect(spent(TargetPlatform.iOS), isFalse);
      expect(spent(TargetPlatform.iOS, refusedBefore: true), isTrue);
    });

    test('Android 13 or later: only after a refusal', () {
      expect(spent(TargetPlatform.android, sdk: 33), isFalse);
      expect(spent(TargetPlatform.android, sdk: 35), isFalse);
      expect(
        spent(TargetPlatform.android, sdk: 33, refusedBefore: true),
        isTrue,
      );
    });

    test('Android below 13: there is no prompt at all', () {
      expect(spent(TargetPlatform.android, sdk: 32), isTrue);
      expect(spent(TargetPlatform.android, sdk: 26), isTrue);
    });

    test('Android with an unknown version: only after a refusal', () {
      expect(spent(TargetPlatform.android), isFalse);
      expect(spent(TargetPlatform.android, refusedBefore: true), isTrue);
    });
  });
}
