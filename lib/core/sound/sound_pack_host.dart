import 'dart:async';

import 'package:critalarm/core/sound/sound_pack.dart';
import 'package:flutter/services.dart';

/// A pack state the platform sent without being asked: download progress, a
/// finished download, a failure.
class SoundPackChange {
  const SoundPackChange(this.packId, this.status);

  final String packId;
  final SoundPackStatus status;
}

/// The native half of the sound packs: Play Asset Delivery on Android, and
/// Apple-hosted Background Assets on iOS 26 and later. Both answer the same
/// calls on one channel.
///
/// Every call is safe with no native side: a missing handler answers
/// [SoundPackState.unsupported], or an empty list.
final class SoundPackHost {
  SoundPackHost([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_handle);
  }

  static const channelName = 'app.critalarm/sound_packs';

  final MethodChannel _channel;
  final _changes = StreamController<SoundPackChange>.broadcast();

  Stream<SoundPackChange> get changes => _changes.stream;

  Future<Object?> _handle(MethodCall call) async {
    if (call.method != 'packStateChanged') return null;
    final args = call.arguments;
    if (args is! Map) return null;
    final pack = args['pack'];
    _changes.add(
      SoundPackChange(
        pack is String ? pack : SoundPacks.library.id,
        SoundPackStatus.fromMap(args),
      ),
    );
    return null;
  }

  /// Where [packId] is right now. Asks the store, never downloads.
  Future<SoundPackStatus> packState(String packId) =>
      _status('packState', packId);

  /// Asks the store for [packId]. Android answers at once and sends the end
  /// on [changes]; iOS answers when the download is over. Progress arrives
  /// on [changes] on both.
  Future<SoundPackStatus> download(String packId) =>
      _status('download', packId);

  /// The folder the store unpacked [packId] into, or null when it is not on
  /// the device. iOS finds the folder through one of the pack's files, so
  /// [soundIds] names them.
  Future<String?> packPath(
    String packId, {
    List<String> soundIds = const [],
  }) async {
    final path = await _invoke<String>('packPath', {
      'pack': packId,
      'ids': soundIds,
    });
    return path == null || path.isEmpty ? null : path;
  }

  /// Copies [soundIds] out of the downloaded pack into the app's sound
  /// folder, where the alarm and the notifications find them. Hands back id
  /// to path for the ones that made it.
  Future<Map<String, String>> installPack(
    String packId,
    List<String> soundIds,
  ) async => _paths(
    await _invoke<List<Object?>>('installPack', {
      'pack': packId,
      'ids': soundIds,
    }),
  );

  /// Which of [soundIds] have a copy in the app's sound folder now, id to
  /// path. Null when the platform could not be asked, which is not the same
  /// as "none": nothing should fall back on a failed question.
  Future<Map<String, String>?> installedPackSounds(
    String packId,
    List<String> soundIds,
  ) async {
    final raw = await _invoke<List<Object?>>('installedPackSounds', {
      'pack': packId,
      'ids': soundIds,
    });
    return raw == null ? null : _paths(raw);
  }

  Future<SoundPackStatus> _status(String method, String packId) async {
    try {
      return SoundPackStatus.fromMap(
        await _channel.invokeMethod<Object?>(method, {'pack': packId}),
      );
    } on MissingPluginException {
      return const SoundPackStatus(SoundPackState.unsupported);
    } on PlatformException {
      return const SoundPackStatus(SoundPackState.failed);
    }
  }

  static Map<String, String> _paths(List<Object?>? raw) => {
    for (final item in raw ?? const <Object?>[])
      if (item is Map &&
          item['id'] is String &&
          item['path'] is String &&
          (item['path'] as String).isNotEmpty)
        item['id'] as String: item['path'] as String,
  };

  Future<T?> _invoke<T>(String method, Object? arguments) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
