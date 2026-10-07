import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/features/settings/domain/priorities/priority_effects.dart';
import 'package:flutter/foundation.dart';

/// What the priorities page is showing.
@immutable
class PrioritiesState {
  const PrioritiesState({
    this.phone,
    this.sound,
    this.isPlaying = false,
  });

  /// Null until the phone's alarm support has been read.
  final PriorityPhone? phone;

  /// The default alarm sound. Null until it has been read.
  final AlarmSound? sound;

  /// True while the preview is playing in the app.
  final bool isPlaying;

  bool get isLoading => phone == null;

  List<PriorityEntry> get entries =>
      phone == null ? const [] : priorityEntriesFor(phone!);

  PrioritiesState copyWith({
    PriorityPhone? phone,
    AlarmSound? sound,
    bool? isPlaying,
  }) => PrioritiesState(
    phone: phone ?? this.phone,
    sound: sound ?? this.sound,
    isPlaying: isPlaying ?? this.isPlaying,
  );
}
