import 'dart:async';
import 'dart:io';

import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/ui_sound/interface_sounds_setting.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/core/ui_sound/playing_paywall_cues.dart';
import 'package:critalarm/core/ui_sound/ui_sound_host.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what it was asked to do, in order.
class _FakePlayer implements UiSoundPlayer {
  final calls = <String>[];

  @override
  void play(String asset, {int voices = 1}) =>
      calls.add(voices == 1 ? 'play $asset' : 'play $asset x$voices');

  @override
  void stop() => calls.add('stop');
}

void main() {
  late _FakePlayer player;
  late List<HapticPattern> taps;
  late int cancels;
  late Duration now;

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
    haptic: hasHaptics ? taps.add : null,
    cancelHaptic: () => cancels += 1,
    clock: () => now,
  );

  setUp(() {
    player = _FakePlayer();
    taps = [];
    cancels = 0;
    now = Duration.zero;
  });

  group('the mute rule', () {
    test('plays only with the switch on and no alarm up', () {
      expect(paywallCueMayPlay(isSwitchOn: true, isAlarmUp: false), isTrue);
      expect(paywallCueMayPlay(isSwitchOn: false, isAlarmUp: false), isFalse);
      expect(paywallCueMayPlay(isSwitchOn: true, isAlarmUp: true), isFalse);
      expect(paywallCueMayPlay(isSwitchOn: false, isAlarmUp: true), isFalse);
    });

    test('the switch off plays nothing, for every cue', () {
      final cues = cuesWith(isSwitchOn: false);
      PaywallCue.values.forEach(cues.play);
      expect(player.calls, isEmpty);
      expect(taps, isEmpty);
    });

    test('an alarm that is up plays nothing, for every cue', () {
      final cues = cuesWith(isAlarmUp: true);
      PaywallCue.values.forEach(cues.play);
      expect(player.calls, isEmpty);
      expect(taps, isEmpty);
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
      // What is left of the cue's haptic goes with it.
      expect(cancels, 1);
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
        ..play(PaywallCue.open.asset!)
        ..play(PaywallCue.bought.asset!)
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
          ..play(PaywallCue.open.asset!)
          ..stop(),
        returnsNormally,
      );
    });
  });

  group('one name, one call', () {
    test('the named methods are the general call', () {
      cuesWith()
        ..open()
        ..gag()
        ..print()
        ..tick()
        ..pickPlan(yearly: true)
        ..pickPlan(yearly: false)
        ..bought()
        ..close();
      final viaPlay = _FakePlayer();
      final cues = PlayingPaywallCues(
        player: viaPlay,
        isSwitchOn: () => true,
        isAlarmUp: () => false,
      );
      [
        PaywallCue.open,
        PaywallCue.gag,
        PaywallCue.print,
        PaywallCue.tick,
        PaywallCue.pickYearly,
        PaywallCue.pickMonthly,
        PaywallCue.bought,
        PaywallCue.close,
      ].forEach(cues.play);
      expect(player.calls, viaPlay.calls);
      expect(player.calls, hasLength(8));
    });

    test('a cue gives its sound and its haptic in the same call', () {
      cuesWith().play(PaywallCue.refuse);
      expect(player.calls, ['play assets/ui_sounds/ui_refuse.m4a']);
      expect(taps, [HapticPattern.doubleKnock]);
    });

    test('a touch only cue taps and leaves the sound alone', () {
      cuesWith()
        ..play(PaywallCue.print)
        ..play(PaywallCue.ratchet);
      expect(player.calls, ['play assets/ui_sounds/ui_print.m4a']);
      expect(taps, [HapticPattern.tick, HapticPattern.tick]);
    });

    test('the silent cues take every cue and do nothing', () {
      const silent = SilentPaywallCues();
      expect(() => PaywallCue.values.forEach(silent.play), returnsNormally);
    });
  });

  group('the cue table', () {
    test('only a touch only cue has no sound, and it has a haptic', () {
      for (final cue in PaywallCue.values) {
        if (cue.sound == null) {
          expect(cue.asset, isNull);
          expect(cue.haptic, isNot(HapticPattern.none), reason: cue.name);
        }
      }
      expect(PaywallCue.ratchet.sound, isNull);
    });

    test('no two cues share a sound', () {
      final sounds = PaywallCue.values.map((cue) => cue.sound).nonNulls;
      expect(sounds.toSet(), hasLength(sounds.length));
    });

    test('what the screen plays by itself, over and over, has no haptic', () {
      expect(PaywallCue.next.haptic, HapticPattern.none);
      expect(PaywallCue.whoosh.haptic, HapticPattern.none);
    });

    test('refuse and its answer feel different', () {
      expect(PaywallCue.refuse.haptic, HapticPattern.doubleKnock);
      expect(PaywallCue.lift.haptic, HapticPattern.risingPair);
    });

    test('only the small quick cues may repeat', () {
      final repeating = PaywallCue.values.where((cue) => cue.mayRepeat);
      expect(repeating, {
        PaywallCue.line,
        PaywallCue.ratchet,
        PaywallCue.roll,
        PaywallCue.check,
        PaywallCue.bulb,
      });
      for (final cue in PaywallCue.values) {
        expect(cue.voices, cue.mayRepeat ? PaywallCue.maxVoices : 1);
        // A cue that repeats never carries more than one pulse.
        if (cue.mayRepeat) expect(cue.haptic.steps, hasLength(1));
      }
      expect(PaywallCue.maxVoices, lessThanOrEqualTo(4));
    });
  });

  group('arriving, buying and leaving', () {
    test('each has a sound and a haptic of its own', () {
      const three = [PaywallCue.open, PaywallCue.bought, PaywallCue.close];
      expect(three.map((cue) => cue.sound).toSet(), hasLength(3));
      expect(three.map((cue) => cue.haptic).toSet(), hasLength(3));
    });

    test('buying rises under the hand and leaving falls', () {
      List<HapticPulse> of(PaywallCue cue) =>
          cue.haptic.steps.map((step) => step.pulse).toList();
      expect(of(PaywallCue.open), [HapticPulse.light]);
      expect(of(PaywallCue.bought), [HapticPulse.light, HapticPulse.medium]);
      expect(of(PaywallCue.close), [HapticPulse.light, HapticPulse.tick]);
    });

    test('leaving does not feel like a failed purchase', () {
      expect(PaywallCue.close.haptic, isNot(PaywallCue.error.haptic));
      expect(PaywallCue.close.sound, isNot(PaywallCue.error.sound));
    });

    test('the falling pair is two pulses and soon over', () {
      const steps = [
        (atMs: 0, pulse: HapticPulse.light),
        (atMs: 110, pulse: HapticPulse.tick),
      ];
      expect(HapticPattern.fallingPair.steps, steps);
      expect(
        const Duration(milliseconds: 110),
        lessThanOrEqualTo(HapticPattern.maxSpan),
      );
    });
  });

  group('the cues of the step after a purchase', () {
    test('each has a sound of its own and one short haptic', () {
      const cues = [
        PaywallCue.settle,
        PaywallCue.lock,
        PaywallCue.key,
        PaywallCue.cord,
        PaywallCue.bulb,
      ];
      for (final cue in cues) {
        expect(cue.sound, 'ui_${cue.name}');
        expect(cue.haptic, isNot(HapticPattern.none));
        expect(cue.haptic.steps.length, lessThanOrEqualTo(2), reason: cue.name);
      }
    });

    test('they are small files: none is long enough to ring', () {
      for (final cue in [
        PaywallCue.settle,
        PaywallCue.lock,
        PaywallCue.key,
        PaywallCue.cord,
        PaywallCue.bulb,
      ]) {
        expect(File(cue.asset!).lengthSync(), lessThan(12 * 1024));
      }
    });

    test('the settle and the bulb are the quiet kind, the cord is felt '
        'as a click and then the light', () {
      expect(PaywallCue.settle.haptic, HapticPattern.tick);
      expect(PaywallCue.bulb.haptic, HapticPattern.tick);
      expect(PaywallCue.cord.haptic, HapticPattern.risingPair);
      expect(PaywallCue.lock.haptic, HapticPattern.medium);
    });
  });

  group('the punchlines of the intros', () {
    const punchlines = [
      PaywallCue.introWink,
      PaywallCue.introGulp,
      PaywallCue.introSpring,
      PaywallCue.introTease,
    ];

    test('each has a sound of its own and a haptic in its rhythm', () {
      expect(punchlines.map((cue) => cue.sound), [
        'ui_intro_wink',
        'ui_intro_gulp',
        'ui_intro_spring',
        'ui_intro_tease',
      ]);
      expect(PaywallCue.introWink.haptic, HapticPattern.tripleRise);
      expect(PaywallCue.introGulp.haptic, HapticPattern.medium);
      expect(PaywallCue.introSpring.haptic, HapticPattern.risingPair);
      expect(PaywallCue.introTease.haptic, HapticPattern.light);
    });

    test('they are small files: none is long enough to ring', () {
      for (final cue in punchlines) {
        expect(File(cue.asset!).lengthSync(), lessThan(12 * 1024));
      }
    });

    test('the one shared release is gone: no cue is named for it', () {
      expect(
        PaywallCue.values.map((cue) => cue.name),
        isNot(contains('kidding')),
      );
      expect(File('assets/ui_sounds/ui_kidding.m4a').existsSync(), isFalse);
    });
  });

  group('cues that repeat fast', () {
    test('five receipt lines are all sent, each allowed to overlap', () {
      final cues = cuesWith();
      for (var i = 0; i < 5; i++) {
        now = Duration(milliseconds: 100 * i);
        cues.play(PaywallCue.line);
      }
      expect(
        player.calls,
        List.filled(5, 'play assets/ui_sounds/ui_line.m4a x3'),
      );
    });

    test('a run of one cue taps three times and then only sounds', () {
      final cues = cuesWith();
      for (var i = 0; i < 5; i++) {
        now = Duration(milliseconds: 100 * i);
        cues.play(PaywallCue.line);
      }
      expect(taps, hasLength(paywallCueTapsPerRun));
      // After a pause it is a new run.
      now += paywallCueRunGap;
      cues.play(PaywallCue.line);
      expect(taps, hasLength(paywallCueTapsPerRun + 1));
    });

    test('another cue in between starts the count again', () {
      final cues = cuesWith();
      for (var i = 0; i < 3; i++) {
        cues.play(PaywallCue.line);
      }
      cues
        ..play(PaywallCue.stamp)
        ..play(PaywallCue.line);
      expect(taps, hasLength(5));
    });

    test('the ratchet follows the finger and is never held back', () {
      final cues = cuesWith();
      for (var i = 0; i < 8; i++) {
        now = Duration(milliseconds: 60 * i);
        cues.play(PaywallCue.ratchet);
      }
      expect(taps, hasLength(8));
      expect(player.calls, isEmpty);
    });

    test('the rule itself', () {
      expect(paywallCueTapMayFire(PaywallCue.line, earlierInRun: 2), isTrue);
      expect(paywallCueTapMayFire(PaywallCue.line, earlierInRun: 3), isFalse);
      expect(paywallCueTapMayFire(PaywallCue.ratchet, earlierInRun: 9), isTrue);
      expect(paywallCueTapMayFire(PaywallCue.next, earlierInRun: 0), isFalse);
    });

    test('the host passes the voices to the native player', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel(UiSoundHost.channelName);
      final seen = <Object?>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            seen.add(call.arguments);
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      UiSoundHost(channel)
        ..play(PaywallCue.line.asset!, voices: PaywallCue.line.voices)
        ..play(PaywallCue.open.asset!);
      await Future<void>.delayed(Duration.zero);
      expect(seen, [
        {'asset': 'assets/ui_sounds/ui_line.m4a', 'voices': 3},
        {'asset': 'assets/ui_sounds/ui_open.m4a', 'voices': 1},
      ]);
    });
  });

  group('the haptic', () {
    test('one haptic with each cue that plays, its own', () {
      cuesWith()
        ..open()
        ..pickPlan(yearly: false)
        ..bought();
      expect(taps, [
        HapticPattern.light,
        HapticPattern.light,
        HapticPattern.risingPair,
      ]);
    });

    test('the switch off means no haptic', () {
      cuesWith(isSwitchOn: false)
        ..open()
        ..bought();
      expect(taps, isEmpty);
    });

    test('an alarm that is up means no haptic', () {
      cuesWith(isAlarmUp: true).open();
      expect(taps, isEmpty);
    });

    test('a platform with no haptics still plays', () {
      cuesWith(hasHaptics: false).open();
      expect(taps, isEmpty);
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

    test('every sound has a file in the interface sounds folder', () {
      for (final cue in PaywallCue.values) {
        final asset = cue.asset;
        if (asset == null) continue;
        expect(asset, startsWith(UiSoundHost.assetFolder));
        expect(File(asset).existsSync(), isTrue, reason: asset);
      }
    });

    test('every file in the folder belongs to a cue', () {
      final used = PaywallCue.values.map((cue) => cue.asset).nonNulls.toSet();
      final onDisk = Directory(UiSoundHost.assetFolder)
          .listSync()
          .map((file) => file.path)
          .where((path) => path.endsWith('.m4a'))
          .toSet();
      expect(onDisk, used);
    });

    test('the names are ones the native player accepts', () {
      final accepted = RegExp(r'^[a-z0-9_]+$');
      for (final cue in PaywallCue.values) {
        final sound = cue.sound;
        if (sound != null) expect(accepted.hasMatch(sound), isTrue);
      }
    });

    test('the whole set stays small', () {
      final bytes = Directory(UiSoundHost.assetFolder)
          .listSync()
          .whereType<File>()
          .fold<int>(0, (sum, file) => sum + file.lengthSync());
      expect(bytes, lessThan(400 * 1024));
    });

    test('no cue is one of the alarm sounds', () {
      final alarmNames = BundledSounds.iosExtensions.keys.toSet();
      for (final cue in PaywallCue.values) {
        final asset = cue.asset;
        if (asset == null) continue;
        expect(asset, isNot(startsWith('assets/sounds/')));
        expect(alarmNames, isNot(contains(cue.sound)));
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
