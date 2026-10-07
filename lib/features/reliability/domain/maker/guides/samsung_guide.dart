import 'package:critalarm/features/reliability/domain/maker/maker_family.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide.dart';
import 'package:critalarm/gen/locale_keys.g.dart';

// Samsung, One UI. Data only: a wrong step is fixed here and in en.json.
//
// "Confirmed" means a page listed under `sources` was read and states the
// step. Nothing below was tried on a phone.
//
// Left out on purpose: the per-app Battery page of One UI 6 and later.
// dontkillmyapp.com names "Don't optimize" for Android 11 to 13 only, and
// no page read for this guide names the newer wording.

const _samsungSupport =
    'https://www.samsung.com/us/support/answer/ANS00088422/';
const _dontKillMyApp = 'https://dontkillmyapp.com/samsung';

const samsungGuide = MakerGuide(
  family: MakerFamily.samsung,
  nameKey: LocaleKeys.maker_guide_samsung_name,
  moreUrl: _dontKillMyApp,
  steps: [
    MakerStep(
      textKey: LocaleKeys.maker_guide_samsung_step_1,
      writtenFor: 'One UI on Android 11 to 14',
      sources: [_samsungSupport, _dontKillMyApp],
      isConfirmed: true,
      note:
          'The Samsung page says Battery and device care, Battery, Background '
          'usage limits. dontkillmyapp.com (Android 13) says Settings, '
          'Battery, Background usage limits.',
    ),
    MakerStep(
      textKey: LocaleKeys.maker_guide_samsung_step_2,
      writtenFor: 'One UI on Android 11 to 14',
      sources: [_samsungSupport],
      isConfirmed: true,
      note:
          'The Samsung page names Never sleeping apps and the + and Add '
          'taps. It does not name an Android or One UI version.',
    ),
    MakerStep(
      textKey: LocaleKeys.maker_guide_samsung_step_3,
      writtenFor: 'One UI on Android 11 to 14',
      sources: [_samsungSupport],
      isConfirmed: true,
      note:
          'The Samsung page lists both sleeping lists and how to remove '
          'an app. It does not say Crit Alarm should be removed; that is '
          'the point of keeping it out of them.',
    ),
  ],
  intents: [
    // Device care, Battery. Names taken from the AutoStarter library
    // (github.com/judemanutd/AutoStarter). No page states that this opens
    // Background usage limits, so it is unconfirmed.
    MakerIntentCandidate.component(
      package: 'com.samsung.android.lool',
      component: 'com.samsung.android.sm.ui.battery.BatteryActivity',
      sources: [_autoStarter],
      note:
          'Named in a library, not on a Samsung page. Which screen it '
          'opens on One UI 5 and later is unknown.',
    ),
    MakerIntentCandidate.component(
      package: 'com.samsung.android.lool',
      component: 'com.samsung.android.sm.battery.ui.BatteryActivity',
      sources: [_autoStarter],
      note:
          'The same library names this second class for newer builds. '
          'Unconfirmed.',
    ),
  ],
);

const _autoStarter =
    'https://github.com/judemanutd/AutoStarter/blob/master/autostarter/src/'
    'main/java/com/judemanutd/autostarter/AutoStartPermissionHelper.kt';
