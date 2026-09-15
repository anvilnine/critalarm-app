import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// An [AlarmHost] backed by a fake channel, so a test can see exactly which
/// native calls were made without a device.
class FakeAlarmHost {
  FakeAlarmHost() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, _handle);
    host = AlarmHost(_channel);
  }

  static const _channel = MethodChannel(AlarmHost.channelName);

  late final AlarmHost host;

  /// Every call the host made, in order.
  final List<MethodCall> calls = [];

  /// Answers the host will give, by method name.
  final Map<String, Object?> answers = {
    'authorizationStatus': 'authorized',
    'requestAuthorization': 'authorized',
    'scheduleAlarm': true,
    'cancelAlarm': true,
    'stopRinging': true,
    'startLocalActivity': true,
    'endActivity': true,
    'showingIncidentIds': <String>[],
    'takePendingActivityTokens': <Object?>[],
    'pushToStartReady': true,
  };

  List<MethodCall> callsTo(String method) =>
      calls.where((c) => c.method == method).toList();

  /// The arguments of every call to [method], typed.
  List<Map<String, Object?>> argsTo(String method) => callsTo(method)
      .map(
        (c) =>
            (c.arguments as Map<Object?, Object?>).cast<String, Object?>(),
      )
      .toList();

  /// The arguments of the one call to [method]. Fails when there was not
  /// exactly one.
  Map<String, Object?> argsOnce(String method) => argsTo(method).single;

  Future<Object?> _handle(MethodCall call) async {
    calls.add(call);
    return answers[call.method];
  }

  /// Plays back what `AppDelegate` sends after it schedules an alarm itself.
  Future<void> emitAlarmScheduled(String incidentId) async {
    await TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .handlePlatformMessage(
          AlarmHost.channelName,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('onAlarmScheduled', incidentId),
          ),
          (_) {},
        );
  }

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}
