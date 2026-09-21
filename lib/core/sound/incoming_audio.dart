import 'package:critalarm/core/sound/sound_import.dart';
import 'package:flutter/foundation.dart';

/// Turns what the platform sent for a shared file into a [PickedSoundFile].
///
/// The native side copies the file into the app's cache first, then sends
/// `{path, name, size_bytes}`. A missing name falls back to the last part of
/// the path. A missing size reads as zero, which [checkPickedSound] calls
/// unreadable. Null when there is no path at all.
PickedSoundFile? pickedSoundFileFrom(Object? raw) {
  if (raw is! Map) return null;
  final path = raw['path'];
  if (path is! String || path.isEmpty) return null;
  final name = raw['name'];
  final size = raw['size_bytes'];
  return PickedSoundFile(
    path: path,
    name: name is String && name.isNotEmpty ? name : path.split('/').last,
    sizeBytes: size is int ? size : 0,
  );
}

/// A sound file another app shared to Crit Alarm, on its way to the cropper.
///
/// The file runs the same check as "Pick a file" as soon as it arrives. A file
/// that passes is held until the app can show the cropper: onboarding has to be
/// finished, and a ringing alarm has to be acknowledged first. The app calls
/// [tryOpen] whenever one of those may have changed.
///
/// Only one file is held. A newer share replaces an older one that never got
/// shown, and the older copy is deleted.
class IncomingAudio {
  IncomingAudio({
    required this.canImportSounds,
    required this.isOnboardingDone,
    required this.isRinging,
    required this.open,
    required this.reject,
    required this.discard,
    required this.platform,
  });

  final Future<bool> Function() canImportSounds;
  final Future<bool> Function() isOnboardingDone;
  final Future<bool> Function() isRinging;

  /// Shows the cropper for the file. The cropper deletes the copy when it
  /// closes, the same as for a picked file.
  final void Function(PickedSoundFile file) open;

  /// Tells the user why the file was turned away.
  final void Function(SoundImportRejection reason) reject;

  /// Deletes a copy nobody will open.
  final Future<void> Function(String path) discard;

  final TargetPlatform platform;

  PickedSoundFile? _pending;
  bool _checking = false;

  /// The file waiting for the cropper, if any.
  PickedSoundFile? get pending => _pending;

  /// A file just came in. Checks it, holds it, and opens it if it can.
  Future<void> receive(PickedSoundFile file) async {
    if (!await canImportSounds()) {
      await discard(file.path);
      return;
    }
    final rejection = checkPickedSound(
      fileName: file.name,
      sizeBytes: file.sizeBytes,
      platform: platform,
    );
    if (rejection != null) {
      await discard(file.path);
      reject(rejection);
      return;
    }
    final older = _pending;
    _pending = file;
    if (older != null && older.path != file.path) await discard(older.path);
    await tryOpen();
  }

  /// Opens the held file if nothing is in the way any more. Safe to call as
  /// often as the app likes: the file opens once.
  Future<void> tryOpen() async {
    if (_checking) return;
    _checking = true;
    try {
      while (true) {
        final file = _pending;
        if (file == null) return;
        if (!await isOnboardingDone()) return;
        if (await isRinging()) return;
        // A newer file came in while the checks ran. Check again for that one.
        if (!identical(file, _pending)) continue;
        _pending = null;
        open(file);
        return;
      }
    } finally {
      _checking = false;
    }
  }
}
