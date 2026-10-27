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
];
