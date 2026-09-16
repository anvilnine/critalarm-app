import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/settings/presentation/settings_health_row.dart';
import 'package:flutter_test/flutter_test.dart';

DevicePermissionItem _missing(DevicePermissionType type, String title) =>
    DevicePermissionItem(
      type: type,
      title: title,
      description: '',
      status: DevicePermissionStatus.denied,
      canFix: true,
    );

/// The Settings Health row used to be hardcoded to a worried face and "1
/// issue", so granting every permission still read as broken.
void main() {
  group('SettingsHealthRow', () {
    test('nothing missing reads as healthy', () {
      final row = SettingsHealthRow.from(const ShellHealth());

      expect(row.isHealthy, isTrue);
      expect(row.faceState, FaceState.calm);
      expect(row.issueCount, 0);
      expect(row.subtitle, 'Everything needed to ring is on');
    });

    test('one missing permission is named', () {
      final row = SettingsHealthRow.from(
        ShellHealth(
          missing: [
            _missing(DevicePermissionType.fullScreenIntent, 'Full screen'),
          ],
        ),
      );

      expect(row.isHealthy, isFalse);
      expect(row.faceState, FaceState.worried);
      expect(row.issueCount, 1);
      expect(row.subtitle, 'Full screen is off.');
    });

    test('more than one missing permission is counted, not guessed', () {
      final row = SettingsHealthRow.from(
        ShellHealth(
          missing: [
            _missing(DevicePermissionType.fullScreenIntent, 'Full screen'),
            _missing(DevicePermissionType.notifications, 'Notifications'),
            _missing(DevicePermissionType.batteryOptimization, 'Battery'),
          ],
        ),
      );

      expect(row.issueCount, 3);
      expect(row.subtitle, '3 settings are off.');
    });
  });
}
