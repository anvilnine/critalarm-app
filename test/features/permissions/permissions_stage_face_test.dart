import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/permissions/presentation/device_permissions_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('permissionsStageFace', () {
    test('all granted is calm', () {
      expect(
        permissionsStageFace(allGranted: true, fullScreenOff: false),
        FaceState.calm,
      );
    });

    test('full-screen intent off is worried', () {
      expect(
        permissionsStageFace(allGranted: false, fullScreenOff: true),
        FaceState.worried,
      );
    });

    test('any other missing permission is dizzy, never alarmed', () {
      expect(
        permissionsStageFace(allGranted: false, fullScreenOff: false),
        FaceState.dizzy,
      );
    });
  });
}
