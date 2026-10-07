import 'package:critalarm/features/reliability/domain/maker/maker_family.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide.dart';
import 'package:critalarm/gen/locale_keys.g.dart';

// Huawei, with Honor. EMUI 6 to 10 is where the steps were found. Newer
// HarmonyOS and Honor MagicOS words were not found on any page that was
// read, so every step carries that in its note. Data only: a wrong step is
// fixed here and in en.json.
//
// "Confirmed" means a page listed under `sources` was read and states the
// step. Nothing below was tried on a phone. dontkillmyapp.com has no Honor
// page (the address gives 404), so Honor links to the Huawei one.

const _dontKillMyApp = 'https://dontkillmyapp.com/huawei';
const _kaspersky =
    'https://support.kaspersky.com/help/KISA/Android_11.71/en-US/195525.htm';
const _honorSupport =
    'https://consumer.huawei.com/ph/support/content/en-us15848660';

const huaweiGuide = MakerGuide(
  family: MakerFamily.huawei,
  nameKey: LocaleKeys.maker_guide_huawei_name,
  moreUrl: _dontKillMyApp,
  steps: [
    MakerStep(
      textKey: LocaleKeys.maker_guide_huawei_step_1,
      writtenFor: 'EMUI 8 to 10',
      sources: [_dontKillMyApp, _kaspersky, _honorSupport],
      isConfirmed: true,
      note:
          'dontkillmyapp.com (EMUI 8, 9, 10) and Kaspersky (EMUI 8, 9) say '
          'Settings, Battery, App launch. The Honor page says search for '
          'App launch. No page read names the HarmonyOS or MagicOS wording.',
    ),
    MakerStep(
      textKey: LocaleKeys.maker_guide_huawei_step_2,
      writtenFor: 'EMUI 8 to 10',
      sources: [_dontKillMyApp, _kaspersky],
      isConfirmed: true,
      note: 'Both pages say to turn off Manage automatically.',
    ),
    MakerStep(
      textKey: LocaleKeys.maker_guide_huawei_step_3,
      writtenFor: 'EMUI 8 to 10',
      sources: [_kaspersky, _honorSupport],
      isConfirmed: true,
      note:
          'Kaspersky names all three: Auto-launch, Secondary launch, Run in '
          'background. The Honor page names the first and the last. '
          'dontkillmyapp.com says to enable all toggles.',
    ),
    MakerStep(
      textKey: LocaleKeys.maker_guide_huawei_step_4,
      writtenFor: 'EMUI 6 to 8',
      sources: [_dontKillMyApp],
      isConfirmed: true,
      note:
          'dontkillmyapp.com: Phone Settings, Advanced Settings, Battery '
          'Manager, Protected apps. Old phones only.',
    ),
  ],
  intents: [
    // Names taken from the AutoStarter library. dontkillmyapp.com names the
    // Startup manager and Protected apps screens, not these classes.
    MakerIntentCandidate.component(
      package: 'com.huawei.systemmanager',
      component:
          'com.huawei.systemmanager.startupmgr.ui.'
          'StartupNormalAppListActivity',
      sources: [_autoStarter, _dontKillMyApp],
      note:
          'The screen (Startup manager) is on the Huawei page. The class '
          'is from a library. It is not the App launch screen the steps '
          'use. Unconfirmed on EMUI 10 and later.',
    ),
    MakerIntentCandidate.component(
      package: 'com.huawei.systemmanager',
      component: 'com.huawei.systemmanager.optimize.process.ProtectActivity',
      sources: [_autoStarter, _dontKillMyApp],
      note:
          'The screen (Protected apps) is on the Huawei page for EMUI 6 '
          'and later. The class is from a library. It is not the App '
          'launch screen the steps use. Unconfirmed.',
    ),
  ],
);

const _autoStarter =
    'https://github.com/judemanutd/AutoStarter/blob/master/autostarter/src/'
    'main/java/com/judemanutd/autostarter/AutoStartPermissionHelper.kt';
