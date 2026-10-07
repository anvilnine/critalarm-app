import 'package:critalarm/features/reliability/domain/maker/maker_guide.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_settings_opener.dart';
import 'package:flutter/services.dart';

/// Asks the Android side, `MakerSettingsChannel`, to try each page. The
/// native `MakerSettingsLauncher` resolves each intent before starting it
/// and catches every failure.
class PlatformMakerSettingsOpener implements MakerSettingsOpener {
  PlatformMakerSettingsOpener({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'app.critalarm/maker_settings';

  final MethodChannel _channel;

  @override
  Future<int> open(List<MakerIntentCandidate> candidates) async {
    try {
      final opened = await _channel.invokeMethod<int>('open', {
        'candidates': [for (final c in candidates) c.toMap()],
      });
      if (opened == null || opened < 0 || opened >= candidates.length) {
        return -1;
      }
      return opened;
    } on PlatformException {
      return -1;
    } on MissingPluginException {
      return -1;
    }
  }
}
