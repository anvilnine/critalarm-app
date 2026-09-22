import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/design/ambient/ambient.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const colors = AppColors.light;
  AmbientProfile at(String path) =>
      AppAmbientShell.profileForPath(path, colors);

  group('AppAmbientShell.profileForPath', () {
    test('the sound list moves the backdrop on from Alarms', () {
      expect(at('/settings/alarms/sounds'), isNot(at('/settings/alarms')));
    });

    test('every way into the sound list shows the same backdrop', () {
      final list = AmbientAppProfiles.soundList(colors);
      expect(at('/sounds'), list);
      expect(at('/settings/alarms/sounds'), list);
      expect(at('/topics/prod/sounds'), list);
    });

    test('the cropper moves the backdrop on from the sound list', () {
      expect(at('/sounds/crop'), isNot(at('/sounds')));
      expect(at('/sounds/crop'), AmbientAppProfiles.soundEditor(colors));
    });

    test('the recorder moves the backdrop on from the sound list', () {
      expect(at('/sounds/record'), isNot(at('/sounds')));
      expect(at('/sounds/record'), AmbientAppProfiles.soundEditor(colors));
    });
  });
}
