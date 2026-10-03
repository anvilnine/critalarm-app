import 'dart:async';

import 'package:critalarm/core/sound/sound_pack_host.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the store on the other end of the sound pack channel: Play's
/// AssetPackManager on Android, Apple's on iOS. Holds what the store says
/// about the pack and which sounds have a copy in the app's sound folder.
class FakeSoundPackPlatform {
  FakeSoundPackPlatform() {
    _messenger.setMockMethodCallHandler(_channel, _handle);
  }

  static const _channel = MethodChannel(SoundPackHost.channelName);
  final TestDefaultBinaryMessenger _messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// What the store answers to `packState`, as the wire word.
  String storeState = 'not_downloaded';

  /// What the store answers to `download`.
  String downloadAnswer = 'downloading';

  /// Ids that a copy fails for, as when the disk is full.
  final Set<String> failCopy = {};

  /// Id to path, for sounds copied into the app's sound folder.
  final Map<String, String> installed = {};

  final List<MethodCall> calls = [];

  /// When true, `packState` never answers, as a store that is offline or
  /// stuck.
  bool hangPackState = false;

  Future<Object?> _handle(MethodCall call) async {
    calls.add(call);
    final args = (call.arguments as Map<Object?, Object?>?) ?? const {};
    final ids = (args['ids'] as List<Object?>? ?? const []).cast<String>();
    switch (call.method) {
      case 'packState':
        if (hangPackState) return Completer<Object?>().future;
        return {'state': storeState};
      case 'download':
        return {'state': downloadAnswer, 'progress': 0.0};
      case 'packPath':
        return storeState == 'downloaded' ? '/pack/${args['pack']}' : null;
      case 'installPack':
        if (storeState != 'downloaded') return <Object?>[];
        for (final id in ids) {
          if (!failCopy.contains(id)) installed[id] = '/sounds/$id.ogg';
        }
        return [
          for (final id in ids)
            if (installed.containsKey(id)) {'id': id, 'path': installed[id]},
        ];
      case 'installedPackSounds':
        return [
          for (final id in ids)
            if (installed.containsKey(id)) {'id': id, 'path': installed[id]},
        ];
    }
    return null;
  }

  /// The store reports progress or the end of a download on its own.
  Future<void> send(String pack, String state, {double? progress}) async {
    if (state == 'downloaded') storeState = 'downloaded';
    await _messenger.handlePlatformMessage(
      SoundPackHost.channelName,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('packStateChanged', {
          'pack': pack,
          'state': state,
          'progress': ?progress,
        }),
      ),
      (_) {},
    );
  }

  void dispose() => _messenger.setMockMethodCallHandler(_channel, null);
}
