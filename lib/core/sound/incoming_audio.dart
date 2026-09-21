import 'dart:async';

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
    required this.discard,
    required this.platform,
  });

  final Future<bool> Function() canImportSounds;
  final Future<bool> Function() isOnboardingDone;
  final Future<bool> Function() isRinging;

  /// Deletes a copy nobody will open.
  final Future<void> Function(String path) discard;

  final TargetPlatform platform;

  // Sync, so a file goes out in the same turn it was let through. The app
  // subscribes before it asks the platform for anything.
  final _toOpen = StreamController<PickedSoundFile>.broadcast(sync: true);
  final _rejected = StreamController<SoundImportRejection>.broadcast(
    sync: true,
  );

  PickedSoundFile? _pending;
  bool _checking = false;

  /// Paths already received. The platform both holds a share and sends it
  /// live, so the same copy can arrive twice; each share gets its own path.
  final Set<String> _seen = {};

  /// Files ready for the cropper. The cropper deletes the copy when it
  /// closes, the same as for a picked file.
  Stream<PickedSoundFile> get toOpen => _toOpen.stream;

  /// Why a shared file was turned away, for the user to see.
  Stream<SoundImportRejection> get rejected => _rejected.stream;

  /// The file waiting for the cropper, if any.
  PickedSoundFile? get pending => _pending;

  /// A file just came in. Checks it, holds it, and opens it if it can.
  Future<void> receive(PickedSoundFile file) async {
    if (!_seen.add(file.path)) return;
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
      _rejected.add(rejection);
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
        _toOpen.add(file);
        return;
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> dispose() async {
    await _toOpen.close();
    await _rejected.close();
  }
}
