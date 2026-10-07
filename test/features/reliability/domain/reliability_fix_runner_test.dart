import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/reliability_fix_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'runs a settings fix and a re-register, and leaves a route to the screen',
    () async {
      final opened = <DevicePermissionType>[];
      var reRegisters = 0;
      final runner = ReliabilityFixRunner(
        openSystemSettings: (permission) async => opened.add(permission),
        reRegisterPushToken: () async {
          reRegisters++;
          return true;
        },
      );

      expect(await runner.run(const OpenRouteFix('testRing')), isFalse);
      expect(opened, isEmpty);
      expect(reRegisters, 0);

      expect(
        await runner.run(
          const OpenSystemSettingsFix(DevicePermissionType.timeSensitive),
        ),
        isTrue,
      );
      expect(opened, [DevicePermissionType.timeSensitive]);

      expect(
        await runner.run(
          const RunFix(ReliabilityFixAction.reRegisterPushToken),
        ),
        isTrue,
      );
      expect(reRegisters, 1);
    },
  );
}
