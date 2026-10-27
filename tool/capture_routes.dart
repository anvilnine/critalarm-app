// Shared by the capture tools under tool/. Not part of the app.

import 'package:critalarm/design/faces/faces.dart';
import 'package:flutter/foundation.dart';

/// One screen a capture tool opens: the file name it is saved under, the
/// route, the mock server fixture it is drawn against, and the platform it is
/// pinned to.
///
/// The platform matters for the sound picker, which shows a different note
/// on iOS. A pinned screen is only meaningful on that one platform, so the
/// tools open it directly instead of walking to it from home.
typedef CaptureRoute = (
  String id,
  String path,
  FaceState fixture,
  TargetPlatform? platform,
);

/// Every screen `tool/capture_all_screens.dart` captures, in file order.
/// `tool/capture_responsive_matrix.dart` captures the same list at tablet,
/// foldable and desktop sizes.
const List<CaptureRoute> allScreenRoutes = [
  ('01_gallery', '/gallery', FaceState.calm, null),
  ('02_onboarding_welcome', '/onboarding', FaceState.calm, null),
  (
    '03_onboarding_permissions',
    '/onboarding/permissions',
    FaceState.alarmed,
    null,
  ),
  ('04_home_face', '/', FaceState.calm, null),
  ('05_topics_list', '/topics', FaceState.calm, null),
  ('06_topic_detail', '/topics/nas-backup', FaceState.worried, null),
  ('07_create_topic', '/topics/new', FaceState.watching, null),
  ('08_critical_alarm', '/alarm', FaceState.alarmed, null),
  ('09_lock_screen', '/lockscreen', FaceState.alarmed, null),
  ('10_settings', '/settings', FaceState.acked, null),
  ('11_paywall_shell', '/paywall', FaceState.acked, null),
  ('12_device_permissions', '/settings/permissions', FaceState.calm, null),
  ('13_permission_denial', '/onboarding/denied', FaceState.worried, null),
  ('14_server_disconnected', '/settings/disconnected', FaceState.calm, null),
  (
    '15_sound_picker_ios',
    '/sounds',
    FaceState.calm,
    TargetPlatform.iOS,
  ),
  // WP2: the lock screen with no alarm over it, and the alarm route with
  // nothing ringing.
  ('wp2_09_lock_screen_quiet', '/lockscreen', FaceState.calm, null),
  ('wp2_08_no_alarm', '/alarm', FaceState.acked, null),
];

/// Screens a capture tool reaches by tapping "I'm up" on a ringing alarm:
/// the acknowledged screen of a real incident, and the acknowledged screen
/// of the phone-only setup test (`inc_demo`). Captured once the tap has
/// settled.
const List<(String id, String path, FaceState fixture)>
acknowledgedCaptureRoutes = [
  ('wp2_08_acked', '/alarm', FaceState.alarmed),
  ('wp2_08_acked_setup_test', '/incidents/inc_demo', FaceState.calm),
];
