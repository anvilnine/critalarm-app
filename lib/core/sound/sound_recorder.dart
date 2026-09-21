import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// The microphone, for recording an alarm sound in the app.
///
/// The only place in the app that knows about the `record` package, so the
/// recorder screen can be tested with a fake.
abstract interface class SoundRecorder {
  /// Asks for the microphone if the user was never asked, and says whether
  /// the app may use it. Once the user said no, the system does not ask
  /// again and this answers false.
  Future<bool> requestPermission();

  /// Starts recording into a new file in the temp folder. Returns the path,
  /// or null when recording could not start.
  Future<String?> start();

  /// Loudness in dBFS (0 is the loudest, about -160 is silence), about every
  /// 70 ms while recording.
  Stream<double> get levels;

  /// Fires when something else took the microphone mid-recording, such as a
  /// phone call.
  Stream<void> get interrupted;

  /// Stops and keeps the file. Returns its path, or null if nothing was
  /// written.
  Future<String?> stop();

  /// Stops and deletes the file.
  Future<void> cancel();

  /// Size of a finished recording, 0 when it is missing.
  Future<int> sizeOf(String path);

  /// Deletes a recording nobody is going to open.
  Future<void> delete(String path);

  /// Opens this app's page in the system settings, where the microphone can
  /// be turned back on.
  Future<void> openSettings();

  Future<void> dispose();
}

/// [SoundRecorder] on top of the `record` package.
///
/// Records AAC-LC into an `.m4a`, mono, 44.1 kHz.
class RecordSoundRecorder implements SoundRecorder {
  RecordSoundRecorder({
    AudioRecorder? recorder,
    MethodChannel settingsChannel = const MethodChannel(
      'app.critalarm/settings',
    ),
  }) : _recorder = recorder ?? AudioRecorder(),
       _settings = settingsChannel;

  static const levelInterval = Duration(milliseconds: 70);

  // The package defaults are AAC-LC at 44.1 kHz, 128 kbps. Only mono is
  // set here.
  static const _config = RecordConfig(numChannels: 1);

  final AudioRecorder _recorder;
  final MethodChannel _settings;
  final _interrupted = StreamController<void>.broadcast();
  StreamSubscription<RecordState>? _stateSub;
  bool _recording = false;

  @override
  Future<bool> requestPermission() => _recorder.hasPermission();

  @override
  Future<String?> start() async {
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(_config, path: path);
      _recording = true;
      // The package pauses by itself when a call or another app takes the
      // microphone. This app never pauses, so a pause means an interruption.
      await _stateSub?.cancel();
      _stateSub = _recorder.onStateChanged().listen((state) {
        if (_recording && state == RecordState.pause) {
          _interrupted.add(null);
        }
      });
      return path;
    } on Exception {
      _recording = false;
      return null;
    }
  }

  @override
  Stream<double> get levels => _recorder
      .onAmplitudeChanged(levelInterval)
      .map((amplitude) => amplitude.current);

  @override
  Stream<void> get interrupted => _interrupted.stream;

  @override
  Future<String?> stop() async {
    _recording = false;
    try {
      return await _recorder.stop();
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    _recording = false;
    try {
      await _recorder.cancel();
    } on Exception {
      // Nothing was recording.
    }
  }

  @override
  Future<int> sizeOf(String path) async {
    try {
      return await File(path).length();
    } on FileSystemException {
      return 0;
    }
  }

  @override
  Future<void> delete(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone, which is what was wanted.
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      await _settings.invokeMethod<bool>('openAppSettings');
    } on MissingPluginException {
      // No settings page to open here.
    } on PlatformException {
      // Same.
    }
  }

  @override
  Future<void> dispose() async {
    await _stateSub?.cancel();
    await _interrupted.close();
    await _recorder.dispose();
  }
}
