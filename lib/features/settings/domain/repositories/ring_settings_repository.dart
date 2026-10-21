import 'package:critalarm/features/settings/domain/entities/ring_settings.dart';

/// Where the two ring switches live.
abstract interface class RingSettingsRepository {
  RingSettings read();

  Future<void> setBrightScreen({required bool on});

  Future<void> setVibrate({required bool on});
}
