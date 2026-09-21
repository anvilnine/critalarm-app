import 'package:critalarm/core/sound/sound_host.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(SoundHost.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('publishing the sound choices calls the platform once', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });

    expect(await SoundHost().publishSoundAssignments(), isTrue);
    expect(calls.single.method, 'publishSoundAssignments');
  });

  test('a platform with no handler answers false', () async {
    expect(await SoundHost().publishSoundAssignments(), isFalse);
  });
}
