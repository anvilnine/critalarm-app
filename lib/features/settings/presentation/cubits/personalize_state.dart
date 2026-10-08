import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/features/settings/domain/personalize/personalize_rules.dart';
import 'package:flutter/foundation.dart';

/// What the Personalize page is showing.
@immutable
class PersonalizeState {
  const PersonalizeState({
    this.isLoading = true,
    this.builtIn = const [],
    this.userSounds = const [],
    this.otherSounds = const [],
    this.defaultSoundId = '',
    this.playingSoundId,
    this.tried,
  });

  final bool isLoading;

  /// The bundled catalogue, in its own order.
  final List<AlarmSound> builtIn;

  /// The sounds the user brought in, oldest first.
  final List<AlarmSound> userSounds;

  /// Downloaded pack sounds, which can be the default too.
  final List<AlarmSound> otherSounds;

  /// The saved default: what really rings.
  final String defaultSoundId;

  /// The sound playing in the preview right now.
  final String? playingSoundId;

  /// A locked option being tried. Never saved.
  final PersonalizeTry? tried;

  SoundStrip get soundStrip => soundStripFor(
    builtIn: builtIn,
    userSounds: userSounds,
    others: otherSounds,
    defaultId: defaultSoundId,
  );

  AlarmSound? soundById(String? id) {
    if (id == null) return null;
    for (final sound in [...builtIn, ...otherSounds, ...userSounds]) {
      if (sound.id == id) return sound;
    }
    return null;
  }

  /// The sound the play button on the preview plays: the one being tried,
  /// or else the saved default.
  AlarmSound? get chosenSound {
    final triedSound = soundById(tried?.optionId);
    return triedSound ?? soundById(defaultSoundId);
  }

  bool get isPlaying => playingSoundId != null;

  PersonalizeState copyWith({
    bool? isLoading,
    List<AlarmSound>? builtIn,
    List<AlarmSound>? userSounds,
    List<AlarmSound>? otherSounds,
    String? defaultSoundId,
    String? playingSoundId,
    bool clearPlaying = false,
    PersonalizeTry? tried,
    bool clearTried = false,
  }) => PersonalizeState(
    isLoading: isLoading ?? this.isLoading,
    builtIn: builtIn ?? this.builtIn,
    userSounds: userSounds ?? this.userSounds,
    otherSounds: otherSounds ?? this.otherSounds,
    defaultSoundId: defaultSoundId ?? this.defaultSoundId,
    playingSoundId: clearPlaying ? null : playingSoundId ?? this.playingSoundId,
    tried: clearTried ? null : tried ?? this.tried,
  );
}
