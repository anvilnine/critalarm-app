import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:flutter/foundation.dart';

/// What the sound picker is showing.
class SoundPickerState {
  const SoundPickerState({
    this.isLoading = true,
    this.bundled = const [],
    this.userSounds = const [],
    this.selectedSoundId = '',
    this.defaultSoundId = '',
    this.topicName,
    this.previewingSoundId,
    this.capabilities = SoundCapabilities.permissive,
    this.errorCode,
    this.platform = TargetPlatform.android,
  });

  final bool isLoading;
  final List<AlarmSound> bundled;
  final List<AlarmSound> userSounds;

  /// The sound this screen is choosing: the topic's, or the global default.
  final String selectedSoundId;

  /// The global default, shown as the fallback line on a per-topic screen.
  final String defaultSoundId;

  /// Null on the settings screen, a topic name when opened from topic detail.
  final String? topicName;

  final String? previewingSoundId;
  final SoundCapabilities capabilities;

  /// One of the `SoundImportRejection` names, or `copyFailed`. The screen
  /// turns it into a sentence.
  final String? errorCode;

  /// Which platform's length limit the rows are checked against.
  final TargetPlatform platform;

  bool get isPerTopic => topicName != null;

  SoundPickerState copyWith({
    bool? isLoading,
    List<AlarmSound>? bundled,
    List<AlarmSound>? userSounds,
    String? selectedSoundId,
    String? defaultSoundId,
    String? topicName,
    String? previewingSoundId,
    bool clearPreviewing = false,
    SoundCapabilities? capabilities,
    String? errorCode,
    bool clearError = false,
    TargetPlatform? platform,
  }) => SoundPickerState(
    isLoading: isLoading ?? this.isLoading,
    bundled: bundled ?? this.bundled,
    userSounds: userSounds ?? this.userSounds,
    selectedSoundId: selectedSoundId ?? this.selectedSoundId,
    defaultSoundId: defaultSoundId ?? this.defaultSoundId,
    topicName: topicName ?? this.topicName,
    previewingSoundId: clearPreviewing
        ? null
        : previewingSoundId ?? this.previewingSoundId,
    capabilities: capabilities ?? this.capabilities,
    errorCode: clearError ? null : errorCode ?? this.errorCode,
    platform: platform ?? this.platform,
  );
}
