import 'package:critalarm/features/reminders/domain/device_time_zone.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:flutter/foundation.dart';

/// Action ids on a reminder notification.
abstract final class ReminderActionIds {
  /// A tap on the body, not a button.
  static const String open = 'open';
  static const String ring = 'ring';
  static const String curl = 'curl';
  static const String signIn = 'sign_in';
  static const String updatePayment = 'update_payment';
  static const String seePro = 'see_pro';

  /// Never reaches Dart as a tap. Native code sets
  /// `reminder_pending_pro_dismiss` instead and the app stays closed.
  static const String notNow = 'not_now';
  static const String rate = 'rate';
  static const String feedback = 'feedback';
}

/// One button on a reminder.
@immutable
final class ReminderAction {
  const ReminderAction({
    required this.id,
    required this.title,
    this.opensApp = true,
  });

  final String id;
  final String title;

  /// iOS `.foreground`. "Ring me now" and every other button open the app;
  /// only "Not now" does not.
  final bool opensApp;

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'opens_app': opensApp,
  };
}

/// Everything the native scheduler needs to post one reminder.
@immutable
final class ReminderRequest {
  const ReminderRequest({
    required this.id,
    required this.kind,
    required this.fireAt,
    required this.title,
    required this.body,
    required this.hiddenPreview,
    required this.channelId,
    required this.faceAsset,
    this.actions = const [],
    this.payload = const {},
  });

  final int id;
  final ReminderKind kind;

  /// Wall-clock. Sent to the platform as fields, never as an instant, so it
  /// fires at that time on the phone's clock whatever the zone.
  final DateTime fireAt;
  final String title;
  final String body;

  /// What shows when previews are hidden on the lock screen.
  final String hiddenPreview;

  /// `ChannelIds.reminders` or `ChannelIds.offers`. Android only.
  final String channelId;

  /// A Flutter asset path under `assets/reminder_faces/`.
  final String faceAsset;
  final List<ReminderAction> actions;
  final Map<String, String> payload;
}

/// A reminder the platform still holds.
@immutable
final class PendingReminder {
  const PendingReminder({required this.id, this.kind, this.fireAt});

  final int id;
  final ReminderKind? kind;

  /// Wall-clock.
  final DateTime? fireAt;
}

/// Whether the OS lets this app post notifications at all.
@immutable
final class ReminderSystemState {
  const ReminderSystemState({required this.notificationsAllowed});

  final bool notificationsAllowed;
}

/// A reminder the user tapped.
@immutable
final class ReminderTap {
  const ReminderTap({
    required this.kind,
    required this.actionId,
    this.payload = const {},
    this.tapId,
  });

  final ReminderKind kind;

  /// A `ReminderActionIds` value.
  final String actionId;
  final Map<String, String> payload;

  /// Tells one tap from the next when it reaches Dart twice.
  final String? tapId;
}

/// The platform did not arm a reminder.
final class ReminderScheduleRefused implements Exception {
  const ReminderScheduleRefused();
}

/// The native reminder scheduler (`app.critalarm/reminders`).
abstract interface class ReminderScheduler {
  /// Throws, for example [ReminderScheduleRefused], when the platform did
  /// not arm it.
  Future<void> schedule(ReminderRequest request);

  /// Cancels pending reminders by id. Delivered ones stay in the tray.
  Future<void> cancel(List<int> ids);

  Future<List<PendingReminder>> pending();

  Future<ReminderSystemState> systemState();

  Future<DeviceTimeZone> deviceTimeZone();

  /// Taps while the app runs.
  Stream<ReminderTap> get taps;

  /// A tap the platform is still holding, taken once.
  Future<ReminderTap?> takePendingTap();
}
