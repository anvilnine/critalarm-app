import 'dart:async';

import 'package:critalarm/core/sound/incoming_audio.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

/// Connects "Share to Crit Alarm" to the running app.
///
/// The platform copies a shared file into the cache and holds it. This asks
/// for it on start and on every resume, and hears about it live while the app
/// runs. [IncomingAudio] decides when the cropper may open; this asks it again
/// whenever something that blocks it may have changed: the route (onboarding
/// finishing, the alarm screen closing) or the incident list (an alarm
/// acknowledged).
class AppIncomingAudioBindings {
  AppIncomingAudioBindings({
    required this._incoming,
    required this._host,
    required this._routeChanges,
    required this._incidentChanges,
    required this._open,
    required this._showMessage,
  });

  final IncomingAudio _incoming;
  final SoundHost _host;
  final Listenable _routeChanges;
  final Stream<Object?> _incidentChanges;
  final void Function(PickedSoundFile file) _open;
  final void Function(String message) _showMessage;

  final List<StreamSubscription<Object?>> _subscriptions = [];

  void start() {
    _subscriptions
      ..add(_incoming.toOpen.listen(_open))
      ..add(_incoming.rejected.listen((r) => _showMessage(messageFor(r))))
      ..add(_host.incomingAudio.listen((f) => unawaited(_incoming.receive(f))))
      ..add(_incidentChanges.listen((_) => _retry()));
    _routeChanges.addListener(_retry);
    unawaited(_takeHeld());
  }

  /// Coming back to the app: a share that arrived while it was away, and a
  /// held file whose alarm may have been acknowledged from the lock screen.
  Future<void> onResumed() async {
    await _takeHeld();
    await _incoming.tryOpen();
  }

  Future<void> _takeHeld() async {
    final file = await _host.takeIncomingAudio();
    if (file != null) await _incoming.receive(file);
  }

  void _retry() => unawaited(_incoming.tryOpen());

  /// What the snackbar says for a shared file that did not pass the check.
  /// The same words as "Pick a file", except for a file nothing could read.
  static String messageFor(
    SoundImportRejection rejection,
  ) => switch (rejection) {
    SoundImportRejection.unreadable =>
      LocaleKeys.sound_share_error_unreadable.tr(),
    SoundImportRejection.unsupportedFormat =>
      LocaleKeys.sound_picker_error_unsupported.tr(),
    SoundImportRejection.tooLarge => LocaleKeys.sound_picker_error_too_large.tr(
      namedArgs: {
        'megabytes': '${SoundImportLimits.maxSourceBytes ~/ (1024 * 1024)}',
      },
    ),
    SoundImportRejection.sourceTooLong =>
      LocaleKeys.sound_picker_error_source_too_long.tr(),
  };

  Future<void> dispose() async {
    _routeChanges.removeListener(_retry);
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}
