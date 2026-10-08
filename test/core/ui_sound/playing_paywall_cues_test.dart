import 'dart:async';
import 'dart:io';

import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/ui_sound/interface_sounds_setting.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/core/ui_sound/playing_paywall_cues.dart';
import 'package:critalarm/core/ui_sound/ui_sound_host.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what it was asked to do, in order.
class _FakePlayer implements UiSoundPlayer {
  final calls = <String>[];

  @override
  void play(String asset) => calls.add('play $asset');

  @override
  void stop() => calls.add('stop');
}

void main() {
  late _FakePlayer player;
  late int taps;

  PlayingPaywallCues cuesWith({
    bool isSwitchOn = true,
    bool isAlarmUp = false,
    Iterable<Stream<Object?>> alarmStarts = const [],
    bool hasHaptics = true,
  }) => PlayingPaywallCues(
    player: player,
    isSwitchOn: () => isSwitchOn,
    isAlarmUp: () => isAlarmUp,
    alarmStarts: alarmStarts,
    haptic: hasHaptics ? () => taps += 1 : null,
  );

  setUp(() {
    player = _FakePlayer();
    taps = 0;
  });

  group('the mute rule', () {
    test('plays only with the switch on and no alarm up', () {
      expect(paywallCueMayPlay(isSwitchOn: true, isAlarmUp: false), isTrue);
      expect(paywallCueMayPlay(isSwitchOn: false, isAlarmUp: false), isFalse);
      expect(paywallCueMayPlay(isSwitchOn: true, isAlarmUp: true), isFalse);
      expect(paywallCueMayPlay(isSwitchOn: false, isAlarmUp: true), isFalse);
    });

    test('the switch off plays nothing, for every cue', () {
      cuesWith(isSwitchOn: false)
        ..open()
        ..gag()
        ..print()
        ..tick()
        ..pickPlan(yearly: true)
        ..pickPlan(yearly: false)
        ..bought()
        ..close();
      expect(player.calls, isEmpty);
    });

    test('an alarm that is up plays nothing, for every cue', () {
      cuesWith(isAlarmUp: true)
        ..open()
        ..gag()
        ..print()
        ..tick()
        ..pickPlan(yearly: true)
        ..pickPlan(yearly: false)
        ..bought()
        ..close();
      expect(player.calls, isEmpty);
    });

    test('the switch and the alarm are read at each cue, not once', () {
      var isSwitchOn = true;
      var isAlarmUp = false;
      final cues = PlayingPaywallCues(
        player: player,
        isSwitchOn: () => isSwitchOn,
        isAlarmUp: () => isAlarmUp,
      )..open();
      isSwitchOn = false;
      cues.tick();
      isSwitchOn = true;
      isAlarmUp = true;
      cues.tick();
      isAlarmUp = false;
      cues.close();
      expect(player.calls, [
        'play assets/ui_sounds/ui_open.m4a',
        'play assets/ui_sounds/ui_close.m4a',
      ]);
    });

    test('an alarm that starts stops the cue in flight', () async {
      final arrivals = StreamController<String>.broadcast();
      final focus = StreamController<bool>.broadcast();
      cuesWith(alarmStarts: [arrivals.stream, focus.stream]).gag();
      arrivals.add('inc_1');
      await Future<void>.delayed(Duration.zero);
      expect(player.calls, ['play assets/ui_sounds/ui_gag.m4a', 'stop']);
      focus.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(player.calls.last, 'stop');
      expect(player.calls, hasLength(3));
      await arrivals.close();
      await focus.close();
    });

    test('after dispose an alarm start is no longer heard', () async {
      final arrivals = StreamController<String>.broadcast();
      final cues = cuesWith(alarmStarts: [arrivals.stream]);
      await cues.dispose();
      arrivals.add('inc_1');
      await Future<void>.delayed(Duration.zero);
      expect(player.calls, isEmpty);
      await arrivals.close();
    });
  });

  group('replace, never queue', () {
    test('each cue goes to the player at once, in the order asked', () {
      cuesWith()
        ..open()
        ..tick()
        ..tick()
        ..pickPlan(yearly: true);
      // No stop and no wait between them: the player replaces what plays.
      expect(player.calls, [
        'play assets/ui_sounds/ui_open.m4a',
        'play assets/ui_sounds/ui_tick.m4a',
        'play assets/ui_sounds/ui_tick.m4a',
        'play assets/ui_sounds/ui_pick_yearly.m4a',
      ]);
    });

    test('the host sends a second play before the first one answers', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel(UiSoundHost.channelName);
      final seen = <String>[];
      final neverAnswers = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) {
            final args = call.arguments;
            seen.add(
              args is Map ? '${call.method} ${args['asset']}' : call.method,
            );
            return neverAnswers.future;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      UiSoundHost(channel)
        ..play(PaywallCueSound.open.asset)
        ..play(PaywallCueSound.bought.asset)
        ..stop();
      await Future<void>.delayed(Duration.zero);
      expect(seen, [
        'play assets/ui_sounds/ui_open.m4a',
        'play assets/ui_sounds/ui_buy.m4a',
        'stop',
      ]);
    });

    test('with no native player the host stays quiet and does not throw', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      expect(
        () => UiSoundHost()
          ..play(PaywallCueSound.open.asset)
          ..stop(),
        returnsNormally,
      );
    });
  });

  group('the tap', () {
    test('one tap with each cue that plays', () {
      cuesWith()
        ..open()
        ..pickPlan(yearly: false)
        ..bought();
      expect(taps, 3);
    });

    test('the switch off means no tap', () {
      cuesWith(isSwitchOn: false)
        ..open()
        ..bought();
      expect(taps, 0);
    });

    test('an alarm that is up means no tap', () {
      cuesWith(isAlarmUp: true).open();
      expect(taps, 0);
    });

    test('a platform with no haptics still plays', () {
      cuesWith(hasHaptics: false).open();
      expect(taps, 0);
      expect(player.calls, ['play assets/ui_sounds/ui_open.m4a']);
    });
  });

  group('the platform choice', () {
    PaywallCues chosenFor({
      required bool isWeb,
      required TargetPlatform platform,
    }) => paywallCuesFor(
      PlatformCapabilities(isWeb: isWeb, platform: platform),
      playing: cuesWith,
    );

    test('iOS and Android play', () {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        expect(
          chosenFor(isWeb: false, platform: platform),
          isA<PlayingPaywallCues>(),
        );
      }
    });

    test('the web stays silent whatever device opens it', () {
      for (final platform in TargetPlatform.values) {
        expect(
          chosenFor(isWeb: true, platform: platform),
          isA<SilentPaywallCues>(),
        );
      }
    });

    test('a desktop build stays silent and never builds the player', () {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        final cues = paywallCuesFor(
          PlatformCapabilities(isWeb: false, platform: platform),
          playing: () => fail('built the playing cues on $platform'),
        );
        expect(cues, isA<SilentPaywallCues>());
      }
    });
  });

  group('the sound files', () {
    test('a plan pick has its own sound for each plan', () {
      cuesWith()
        ..pickPlan(yearly: true)
        ..pickPlan(yearly: false);
      expect(player.calls, [
        'play assets/ui_sounds/ui_pick_yearly.m4a',
        'play assets/ui_sounds/ui_pick_monthly.m4a',
      ]);
    });

    test('every cue has a file in the interface sounds folder', () {
      for (final sound in PaywallCueSound.values) {
        expect(sound.asset, startsWith(UiSoundHost.assetFolder));
        expect(File(sound.asset).existsSync(), isTrue, reason: sound.asset);
      }
    });

    test('no cue is one of the alarm sounds', () {
      final alarmNames = BundledSounds.iosExtensions.keys.toSet();
      for (final sound in PaywallCueSound.values) {
        expect(sound.asset, isNot(startsWith('assets/sounds/')));
        expect(alarmNames, isNot(contains(sound.fileName)));
      }
    });
  });

  group('the Interface sounds switch', () {
    test(
      'is on until the user turns it off, and the choice is saved',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final setting = InterfaceSoundsSetting(prefs);
        expect(setting.isOn, isTrue);

        await setting.set(isOn: false);
        expect(setting.isOn, isFalse);
        expect(setting.listenable.value, isFalse);
        expect(prefs.getBool(InterfaceSoundsSetting.prefsKey), isFalse);
        expect(InterfaceSoundsSetting(prefs).isOn, isFalse);
      },
    );
  });
}
