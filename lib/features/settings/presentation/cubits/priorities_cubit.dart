import 'dart:async';

import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/own_sound_rule.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_pack_repository.dart';
import 'package:critalarm/features/settings/domain/priorities/priority_effects.dart';
import 'package:critalarm/features/settings/domain/repositories/alarm_sound_repository.dart';
import 'package:critalarm/features/settings/presentation/cubits/priorities_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the priorities page: which phone this is, and the in-app preview of
/// the default alarm sound.
///
/// The preview goes through [SoundHost], the same player the sound screens
/// use. It schedules no alarm, posts no notification and calls no server, so
/// nothing here can open an incident. It stops when the page closes and when
/// the app leaves the foreground.
class PrioritiesCubit extends Cubit<PrioritiesState> {
  PrioritiesCubit(
    this._alarm,
    this._sound,
    this._sounds, {
    this._packs,
    TargetPlatform? platform,
    this.isWeb = false,
    this.nameOf,
    this._ownSoundsLocked,
  }) : _platform = platform ?? defaultTargetPlatform,
       super(const PrioritiesState()) {
    _previewEnded = _sound.previewEnded.listen((path) {
      final playing = state.sound;
      // A late event for an older preview says nothing about this one.
      if (!isClosed && state.isPlaying && playing?.path == path) {
        emit(state.copyWith(isPlaying: false));
      }
    });
  }

  final AlarmHost _alarm;
  final SoundHost _sound;
  final AlarmSoundRepository _sounds;
  final SoundPackRepository? _packs;
  final TargetPlatform _platform;

  /// From PlatformCapabilities, because features never read the web flag.
  final bool isWeb;

  /// Turns a sound id into a name in the user's language. Null in tests.
  final String Function(String id)? nameOf;

  /// Whether own sounds are locked. Left out, they count as open.
  final bool Function()? _ownSoundsLocked;

  late final StreamSubscription<String> _previewEnded;

  Future<void> load() async {
    // The host answers "unsupported" when it cannot be reached, which
    // RingClaim reads as the quiet wording on an iPhone.
    final authorization = await _alarm.authorizationStatus();
    final phone = priorityPhoneFor(
      platform: _platform,
      isWeb: isWeb,
      claim: RingClaim.forPhone(
        authorization,
        platform: _platform,
        isWeb: isWeb,
      ),
    );
    final sound = await _defaultSound();
    if (isClosed) return;
    emit(state.copyWith(phone: phone, sound: sound));
  }

  /// The sound a critical topic rings with unless it picked its own. A sound
  /// that is gone falls back to the bundled default, as the alarm does.
  Future<AlarmSound> _defaultSound() async {
    final assignments = (await _sounds.getAssignments()).getOrNull();
    // What really rings: a locked own sound is not it.
    final id = assignments == null
        ? BundledSounds.fallbackId
        : OwnSoundRule.ringingDefaultId(
            saved: assignments,
            ownSoundsLocked: _ownSoundsLocked?.call() ?? false,
          );
    final bundled = BundledSounds.catalogue(
      platform: _platform,
      nameOf: nameOf,
    );
    final user = (await _sounds.getUserSounds()).getOrDefault(const []);
    final packSounds =
        await _packs?.installedSounds(nameOf: nameOf) ?? const <AlarmSound>[];
    for (final sound in [...bundled, ...packSounds, ...user]) {
      if (sound.id == id) return sound;
    }
    return bundled.firstWhere((s) => s.id == BundledSounds.fallbackId);
  }

  /// The play button. A second tap stops it.
  Future<void> togglePreview() async {
    final sound = state.sound;
    if (sound == null) return;
    if (state.isPlaying) {
      await stopPreview();
      return;
    }
    final started = await _sound.startPreview(sound);
    if (isClosed) {
      // The page closed while the host was starting. Close already asked it
      // to stop, but the start may have landed after that.
      await _sound.stopPreview();
      return;
    }
    emit(state.copyWith(isPlaying: started));
  }

  Future<void> stopPreview() async {
    if (!state.isPlaying) return;
    if (!isClosed) emit(state.copyWith(isPlaying: false));
    await _sound.stopPreview();
  }

  /// Anything but the foreground stops the preview. A call, the control
  /// centre and the home button all count, so a sound never plays on for a
  /// page nobody is looking at.
  Future<void> onLifecycle(AppLifecycleState lifecycle) async {
    if (lifecycle == AppLifecycleState.resumed) return;
    await stopPreview();
  }

  @override
  Future<void> close() async {
    await _previewEnded.cancel();
    await _sound.stopPreview();
    return super.close();
  }
}
