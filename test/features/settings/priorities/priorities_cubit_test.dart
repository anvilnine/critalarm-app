import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/features/settings/domain/priorities/priority_effects.dart';
import 'package:critalarm/features/settings/presentation/cubits/priorities_cubit.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../memory_alarm_sound_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const soundChannel = MethodChannel(SoundHost.channelName);
  const alarmChannel = MethodChannel(AlarmHost.channelName);

  /// Every call that reached the sound channel, in order.
  late List<MethodCall> soundCalls;

  /// Every call that reached the alarm channel. The page may only ask for the
  /// authorization status: never schedule, never stop.
  late List<String> alarmCalls;

  late String authorization;
  late bool startSucceeds;
  late MemoryAlarmSoundRepository repository;
  late SoundHost host;

  PrioritiesCubit build({TargetPlatform platform = TargetPlatform.iOS}) =>
      PrioritiesCubit(
        AlarmHost(),
        host,
        repository,
        platform: platform,
      );

  List<String> soundMethods() => [for (final c in soundCalls) c.method];

  setUp(() {
    soundCalls = [];
    alarmCalls = [];
    authorization = 'authorized';
    startSucceeds = true;
    repository = MemoryAlarmSoundRepository();
    messenger
      ..setMockMethodCallHandler(soundChannel, (call) async {
        soundCalls.add(call);
        if (call.method == 'startPreview') return startSucceeds;
        return true;
      })
      ..setMockMethodCallHandler(alarmChannel, (call) async {
        alarmCalls.add(call.method);
        return call.method == 'authorizationStatus' ? authorization : null;
      });
    host = SoundHost();
  });

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(soundChannel, null)
      ..setMockMethodCallHandler(alarmChannel, null);
  });

  group('load', () {
    test('an iPhone with AlarmKit gets the alarm lines', () async {
      final cubit = build();
      await cubit.load();
      expect(cubit.state.phone, PriorityPhone.iosAlarm);
      expect(cubit.state.entries.first.line, PriorityLine.alarmIos);
      await cubit.close();
    });

    test('an iPhone without AlarmKit gets the Time-Sensitive lines', () async {
      authorization = 'unsupported';
      final cubit = build();
      await cubit.load();
      expect(cubit.state.phone, PriorityPhone.iosTimeSensitive);
      expect(cubit.state.entries.first.line, PriorityLine.timeSensitiveIos);
      await cubit.close();
    });

    test('Android gets the full-screen lines', () async {
      authorization = 'unsupported';
      final cubit = build(platform: TargetPlatform.android);
      await cubit.load();
      expect(cubit.state.phone, PriorityPhone.android);
      expect(cubit.state.entries.first.line, PriorityLine.alarmAndroid);
      await cubit.close();
    });

    test('the sound is the default alarm sound', () async {
      await repository.setDefaultSoundId('pager_beep');
      final cubit = build();
      await cubit.load();
      expect(cubit.state.sound?.id, 'pager_beep');
      await cubit.close();
    });

    test('a user sound that is the default is the one heard', () async {
      const mine = AlarmSound(
        id: 'user_1',
        name: 'Air horn',
        source: AlarmSoundSource.user,
        path: '/sounds/user_1.caf',
        duration: Duration(seconds: 4),
      );
      repository.sounds.add(mine);
      await repository.setDefaultSoundId('user_1');
      final cubit = build();
      await cubit.load();
      expect(cubit.state.sound, mine);
      await cubit.close();
    });

    test(
      'a default that no longer exists falls back to the bundled one',
      () async {
        await repository.setDefaultSoundId('gone');
        final cubit = build();
        await cubit.load();
        expect(cubit.state.sound?.id, BundledSounds.fallbackId);
        await cubit.close();
      },
    );
  });

  group('preview', () {
    test('play starts the sound in the app and nothing else', () async {
      final cubit = build();
      await cubit.load();
      await cubit.togglePreview();

      expect(cubit.state.isPlaying, isTrue);
      expect(soundMethods(), ['startPreview']);
      final args = soundCalls.single.arguments as Map<Object?, Object?>;
      expect(args['path'], cubit.state.sound!.path);
      // No alarm was scheduled or stopped. Only the status was read.
      expect(alarmCalls, ['authorizationStatus']);
      await cubit.close();
    });

    test('a second tap stops it', () async {
      final cubit = build();
      await cubit.load();
      await cubit.togglePreview();
      await cubit.togglePreview();

      expect(cubit.state.isPlaying, isFalse);
      expect(soundMethods(), ['startPreview', 'stopPreview']);
      await cubit.close();
    });

    test(
      'a preview the phone could not start does not show as playing',
      () async {
        startSucceeds = false;
        final cubit = build();
        await cubit.load();
        await cubit.togglePreview();

        expect(cubit.state.isPlaying, isFalse);
        await cubit.close();
      },
    );

    test('a preview that ends on its own clears the playing state', () async {
      final cubit = build();
      await cubit.load();
      await cubit.togglePreview();
      final path = cubit.state.sound!.path;

      await messenger.handlePlatformMessage(
        SoundHost.channelName,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('previewEnded', {'path': path}),
        ),
        (_) {},
      );

      expect(cubit.state.isPlaying, isFalse);
      await cubit.close();
    });

    test('nothing plays before the sound is known', () async {
      final cubit = build();
      await cubit.togglePreview();
      expect(soundMethods(), isEmpty);
      await cubit.close();
    });
  });

  group('stopping', () {
    test('closing the page stops the sound', () async {
      final cubit = build();
      await cubit.load();
      await cubit.togglePreview();
      soundCalls.clear();

      await cubit.close();

      expect(soundMethods(), contains('stopPreview'));
    });

    test('closing the page stops a sound that was not playing too', () async {
      final cubit = build();
      await cubit.load();
      await cubit.close();
      expect(soundMethods(), ['stopPreview']);
    });

    for (final lifecycle in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ]) {
      test('leaving the foreground ($lifecycle) stops the sound', () async {
        final cubit = build();
        await cubit.load();
        await cubit.togglePreview();
        soundCalls.clear();

        await cubit.onLifecycle(lifecycle);

        expect(cubit.state.isPlaying, isFalse);
        expect(soundMethods(), ['stopPreview']);
        await cubit.close();
      });
    }

    test(
      'coming back to the foreground leaves a playing sound alone',
      () async {
        final cubit = build();
        await cubit.load();
        await cubit.togglePreview();
        soundCalls.clear();

        await cubit.onLifecycle(AppLifecycleState.resumed);

        expect(cubit.state.isPlaying, isTrue);
        expect(soundMethods(), isEmpty);
        await cubit.close();
      },
    );
  });
}
