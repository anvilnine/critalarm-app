// Shared by the capture tools under tool/. Not part of the app.

import 'package:critalarm/design/faces/faces.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
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
  // WP6. The welcome pages themselves: on a phone /onboarding is the
  // permissions step, which waits on the phone's answers in a capture.
  ('wp6_02_welcome_pages', '/onboarding/welcome', FaceState.calm, null),
  // WP6. New topic as the first_topic setup step.
  ('wp6_07_first_topic', '/onboarding/first-topic', FaceState.calm, null),
  // WP2: the lock screen with no alarm over it, and the alarm route with
  // nothing ringing.
  ('wp2_09_lock_screen_quiet', '/lockscreen', FaceState.calm, null),
  ('wp2_08_no_alarm', '/alarm', FaceState.acked, null),
  // WP5: the other paywall layouts a place opens, to check the one column
  // and the frame on wide windows.
  ('wp5_paywall_sheet', '/plans/sheet?product=hosted', FaceState.acked, null),
  ('wp5_paywall_proof', '/plans/proof?product=hosted', FaceState.acked, null),
  ('wp5_paywall_reel', '/plans/reel?product=hosted', FaceState.acked, null),
  ('wp5_paywall_wipe', '/plans/wipe?product=hosted', FaceState.acked, null),
  ('wp5_paywall_pro', '/plans/hero?product=pro', FaceState.acked, null),
  // The topic link on an expanded window opens Home with the topic in the
  // pane. The calm fixture lists prod-db first, so a pane on nas-backup is
  // the link's doing.
  ('wp3_topic_deep_link', '/topics/nas-backup', FaceState.calm, null),
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

/// A screen captured after one tap: the file name, the route, the fixture,
/// and the `LocaleKeys` key of the text the tool taps once the screen has
/// drawn. Unlike the picks in `tool/capture_responsive_matrix.dart`, it is
/// captured at every size, so the same tap shows what one pane and two panes
/// each do with it.
typedef CaptureTapRoute = (
  String id,
  String path,
  FaceState fixture,
  String tapKey,
);

/// The tap captures `tool/capture_responsive_matrix.dart` adds to its list.
const List<CaptureTapRoute> tapScreenRoutes = [
  // WP4: Server opens in the Settings detail pane with the URL unchanged
  // where there is a pane, and pushes /settings/server where there is none.
  (
    'wp4_settings_tap_server',
    '/settings',
    FaceState.acked,
    LocaleKeys.settings_server_row_title,
  ),
  // WP4: the Personalize pass stack in the pane, with no back ring.
  (
    'wp4_settings_tap_personalize',
    '/settings',
    FaceState.acked,
    LocaleKeys.personalize_title,
  ),
  // WP4: on a phone that lost its server the pane opens on Server, and the
  // Server page and the Server row read one state (both Disconnected).
  (
    'wp4_disconnected_tap_server',
    '/settings/disconnected',
    FaceState.calm,
    LocaleKeys.settings_server_row_title,
  ),
  // WP4: Storage opens in the pane and every row value beside it stays as
  // it was.
  (
    'wp4_settings_tap_storage',
    '/settings',
    FaceState.acked,
    LocaleKeys.settings_storage_row_title,
  ),
];

/// A second tap some tap captures make inside the Settings detail pane,
/// once the first tap has opened a page there: the capture id and the
/// `LocaleKeys` key of the text tapped on that page. It is the tap a person
/// would make next. Where there is no pane the capture stops after the
/// first tap, so the phone captures stay as they were.
const Map<String, String> paneTapRoutes = {
  // WP4: a new retention picked on the Storage page in the pane shows in the
  // Storage row beside it at once (Keep all, then 1 month).
  'wp4_settings_tap_storage': LocaleKeys.settings_storage_delete_1m,
};
