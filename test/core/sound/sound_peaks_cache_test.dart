import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_peaks_cache.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(SoundHost.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  const pager = AlarmSound(
    id: 'pager_beep',
    name: 'Pager beep',
    source: AlarmSoundSource.bundled,
    path: 'assets/sounds/pager_beep.mp3',
    duration: Duration(seconds: 14),
  );

  late List<MethodCall> calls;
  late Object? answer;

  setUp(() {
    calls = [];
    answer = [0.2, 1.0];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return answer;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('reads a bundled sound once, however often it is asked', () async {
    final cache = SoundPeaksCache(SoundHost());
    final both = await Future.wait([cache.load(pager), cache.load(pager)]);
    final again = await cache.load(pager);

    expect(both, [
      [0.2, 1.0],
      [0.2, 1.0],
    ]);
    expect(again, [0.2, 1.0]);
    expect(calls, hasLength(1));
    expect(calls.single.arguments, {
      'path': 'assets/sounds/pager_beep.mp3',
      'is_asset': true,
      'count': SoundPeaksCache.barCount,
    });
    expect(cache.cached(pager.id), [0.2, 1.0]);
  });

  test('an empty answer is not kept, so the next open tries again', () async {
    answer = null;
    final cache = SoundPeaksCache(SoundHost());
    expect(await cache.load(pager), isEmpty);
    expect(cache.cached(pager.id), isNull);

    answer = [0.5];
    expect(await cache.load(pager), [0.5]);
    expect(calls, hasLength(2));
  });
}
