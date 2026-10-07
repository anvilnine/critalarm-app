import 'package:critalarm/features/reliability/domain/scheduled_summary_reader.dart';
import 'package:flutter/services.dart';

/// Asks the iOS settings channel, `checkScheduledSummary`
/// (`AppDelegate.handleSettingsCall`). Only iOS answers, so the source only
/// calls it there.
class PlatformScheduledSummaryReader implements ScheduledSummaryReader {
  PlatformScheduledSummaryReader({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('app.critalarm/settings');

  final MethodChannel _channel;

  @override
  Future<bool> isInScheduledSummary() async {
    try {
      return await _channel.invokeMethod<bool>('checkScheduledSummary') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
