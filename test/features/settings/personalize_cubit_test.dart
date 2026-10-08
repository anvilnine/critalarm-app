import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/features/settings/domain/personalize/personalize_rules.dart';
import 'package:critalarm/features/settings/presentation/cubits/personalize_cubit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_alarm_sound_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(SoundHost.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late MemoryAlarmSoundRepository repository;
  late SoundHost host;
  late PersonalizeCubit cubit;

  const own = AlarmSound(
    id: 'user_1',
    name: 'Air horn',
    source: AlarmSoundSource.user,
    path: '/sounds/user_1.caf',
    duration: Duration(seconds: 4),
  );

  List<String> methods() => [for (final call in calls) call.method];

  setUp(() async {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    repository = MemoryAlarmSoundRepository();
    host = SoundHost(channel);
    cubit = PersonalizeCubit(
      repository,
      host,
      platform: TargetPlatform.iOS,
    );
    await cubit.load();
    calls.clear();
  });

  tearDown(() async {
    await cubit.close();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('opens on the saved default with the built-in sounds', () {
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.defaultSoundId, BundledSounds.fallbackId);
    expect(
      cubit.state.soundStrip(ownSoundsLocked: false).current?.id,
      BundledSounds.fallbackId,
    );
    expect(
      cubit.state.soundStrip(ownSoundsLocked: false).builtIns,
      hasLength(soundStripBuiltIns),
    );
    expect(cubit.state.tried, isNull);
  });

  test('picking a sound saves it where the sound picker reads it', () async {
    final pick = cubit.state.soundStrip(ownSoundsLocked: false).builtIns.first;
    await cubit.pickSound(pick);

    expect(repository.assignments.defaultSoundId, pick.id);
    expect(cubit.state.defaultSoundId, pick.id);
    expect(cubit.state.playingSoundId, pick.id);
    expect(methods(), [
      'publishSoundAssignments',
      'stopPreview',
      'startPreview',
    ]);
  });

  test('a default changed in the sound picker shows after a reload', () async {
    await repository.setDefaultSoundId('pager_beep');
    await cubit.load();
    expect(
      cubit.state.soundStrip(ownSoundsLocked: false).current?.id,
      'pager_beep',
    );
  });

  test('trying a locked own sound plays it and saves nothing', () async {
    repository.sounds.add(own);
    await cubit.load();
    calls.clear();

    await cubit.trySound(own);

    expect(repository.assignments.defaultSoundId, BundledSounds.fallbackId);
    expect(cubit.state.defaultSoundId, BundledSounds.fallbackId);
    expect(
      cubit.state.tried,
      const PersonalizeTry(AppFeature.ownSounds, optionId: 'user_1'),
    );
    expect(cubit.state.playingSoundId, 'user_1');
    expect(cubit.state.chosenSound(ownSoundsLocked: true)?.id, 'user_1');
    expect(methods(), isNot(contains('publishSoundAssignments')));
  });

  test('locked with an own sound saved: the play button plays what rings, '
      'and the saved choice stays', () async {
    repository.sounds.add(own);
    await repository.setDefaultSoundId(own.id);
    await cubit.load();
    calls.clear();

    expect(
      cubit.state.soundStrip(ownSoundsLocked: true).current?.id,
      BundledSounds.fallbackId,
    );
    await cubit.togglePlay(ownSoundsLocked: true);

    expect(cubit.state.playingSoundId, BundledSounds.fallbackId);
    expect(repository.assignments.defaultSoundId, own.id);
  });

  test('picking a free sound ends the try', () async {
    repository.sounds.add(own);
    await cubit.load();
    await cubit.trySound(own);
    await cubit.pickSound(
      cubit.state.soundStrip(ownSoundsLocked: false).builtIns.first,
    );
    expect(cubit.state.tried, isNull);
  });

  test('the play button plays the chosen sound once, then stops it', () async {
    await cubit.togglePlay(ownSoundsLocked: false);
    expect(cubit.state.playingSoundId, BundledSounds.fallbackId);
    final start = calls.lastWhere((call) => call.method == 'startPreview');
    expect((start.arguments as Map)['is_asset'], isTrue);

    await cubit.togglePlay(ownSoundsLocked: false);
    expect(cubit.state.isPlaying, isFalse);
    expect(methods().last, 'stopPreview');
  });

  test('a preview that ends on its own clears the play button', () async {
    await cubit.togglePlay(ownSoundsLocked: false);
    final path = cubit.state.chosenSound(ownSoundsLocked: false)!.path;
    await messenger.handlePlatformMessage(
      SoundHost.channelName,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('previewEnded', {'path': path}),
      ),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.isPlaying, isFalse);
  });

  test('the page only ever asks the sound host to preview', () async {
    repository.sounds.add(own);
    await cubit.load();
    await cubit.pickSound(
      cubit.state.soundStrip(ownSoundsLocked: false).builtIns.first,
    );
    await cubit.trySound(own);
    await cubit.togglePlay(ownSoundsLocked: false);
    await cubit.togglePlay(ownSoundsLocked: false);
    expect(
      methods().toSet(),
      {'publishSoundAssignments', 'stopPreview', 'startPreview'},
    );
  });

  test('closing the page stops the sound', () async {
    await cubit.togglePlay(ownSoundsLocked: false);
    calls.clear();
    await cubit.close();
    expect(methods(), contains('stopPreview'));
    cubit = PersonalizeCubit(repository, host);
  });
}
