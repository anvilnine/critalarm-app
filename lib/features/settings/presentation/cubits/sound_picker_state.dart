import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/own_sound_rule.dart';
import 'package:critalarm/core/sound/sound_assignments.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_pack.dart';
import 'package:flutter/foundation.dart';

/// One row in "Sound packs": the pack and where it is.
@immutable
class SoundPackEntry {
  const SoundPackEntry(this.pack, this.status);

  final SoundPack pack;
  final SoundPackStatus status;

  SoundPackEntry withStatus(SoundPackStatus next) => SoundPackEntry(pack, next);
}

/// What the sound picker is showing.
class SoundPickerState {
  const SoundPickerState({
    this.isLoading = true,
    this.bundled = const [],
    this.userSounds = const [],
    this.packs = const [],
    this.packSounds = const [],
    this.selectedSoundId = '',
    this.defaultSoundId = '',
    this.topicName,
    this.previewingSoundId,
    this.capabilities = SoundCapabilities.permissive,
    this.errorCode,
    this.platform = TargetPlatform.android,
    this.isLoadingPeaks = true,
    this.ownSounds = const FeatureDecision.open(),
  });

  final bool isLoading;

  /// True until every waveform the list can read has been read.
  final bool isLoadingPeaks;
  final List<AlarmSound> bundled;
  final List<AlarmSound> userSounds;

  /// The packs the store offers, empty where there are none (the web).
  final List<SoundPackEntry> packs;

  /// Sounds from downloaded packs, listed under their pack.
  final List<AlarmSound> packSounds;

  /// Every sound the screen can show, for looking one up by id.
  List<AlarmSound> get allSounds => [...bundled, ...packSounds, ...userSounds];

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

  /// The access layer's answer for own sounds. Handed to the paywall door
  /// as it is when a locked way in is tapped.
  final FeatureDecision ownSounds;

  /// Whether own sounds are locked: listed, and not selectable.
  bool get ownSoundsLocked => ownSoundsLockedBy(ownSounds);

  /// Whether [sound] is one of the person's own and locked right now.
  bool isLocked(AlarmSound sound) =>
      ownSoundsLocked && sound.source == AlarmSoundSource.user;

  /// The sound that really rings for this screen's choice. The same as
  /// [selectedSoundId] unless that is an own sound and own sounds are
  /// locked.
  String get ringingSoundId {
    final topic = topicName;
    return OwnSoundRule.ringingSoundId(
      saved: SoundAssignments(
        defaultSoundId: defaultSoundId,
        perTopic: topic == null ? const {} : {topic: selectedSoundId},
      ),
      ownSoundsLocked: ownSoundsLocked,
      topicName: topic,
    );
  }

  /// True when the saved choice is a locked own sound, so something else
  /// rings in its place.
  bool get ringsSomethingElse => ringingSoundId != selectedSoundId;

  SoundPickerState copyWith({
    bool? isLoading,
    List<AlarmSound>? bundled,
    List<AlarmSound>? userSounds,
    List<SoundPackEntry>? packs,
    List<AlarmSound>? packSounds,
    String? selectedSoundId,
    String? defaultSoundId,
    String? topicName,
    String? previewingSoundId,
    bool clearPreviewing = false,
    SoundCapabilities? capabilities,
    String? errorCode,
    bool clearError = false,
    TargetPlatform? platform,
    bool? isLoadingPeaks,
    FeatureDecision? ownSounds,
  }) => SoundPickerState(
    ownSounds: ownSounds ?? this.ownSounds,
    isLoadingPeaks: isLoadingPeaks ?? this.isLoadingPeaks,
    isLoading: isLoading ?? this.isLoading,
    bundled: bundled ?? this.bundled,
    userSounds: userSounds ?? this.userSounds,
    packs: packs ?? this.packs,
    packSounds: packSounds ?? this.packSounds,
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
