import 'package:critalarm/features/reliability/domain/maker/maker_family.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide.dart';
import 'package:critalarm/gen/locale_keys.g.dart';

// Xiaomi, with Redmi and Poco. MIUI 12 to 14 and HyperOS. Data only: a wrong
// step is fixed here and in en.json.
//
// "Confirmed" means a page listed under `sources` was read and states the
// step. Nothing below was tried on a phone. The Xiaomi support pages
// (mi.com) refused to load, so the HyperOS wording rests on search result
// text and third-party guides, and is marked unconfirmed where it matters.

const _dontKillMyApp = 'https://dontkillmyapp.com/xiaomi';
const _miBatterySaver = 'https://www.mi.com/global/support/article/KA-33239/';
const _miAutostart = 'https://www.mi.com/global/support/faq/details/KA-507611/';

const xiaomiGuide = MakerGuide(
  family: MakerFamily.xiaomi,
  nameKey: LocaleKeys.maker_guide_xiaomi_name,
  moreUrl: _dontKillMyApp,
  steps: [
    MakerStep(
      textKey: LocaleKeys.maker_guide_xiaomi_step_1,
      writtenFor: 'MIUI 14, HyperOS',
      sources: [_dontKillMyApp],
      isConfirmed: false,
      note:
          'dontkillmyapp.com (MIUI 14) says Settings, Apps, your app. The '
          '"Manage apps" first tap on HyperOS comes from search result '
          'text and third-party guides, not a page that was read.',
    ),
    MakerStep(
      textKey: LocaleKeys.maker_guide_xiaomi_step_2,
      writtenFor: 'MIUI 14 (Background autostart), older MIUI (Autostart)',
      sources: [_dontKillMyApp, _miAutostart],
      isConfirmed: true,
      note:
          'dontkillmyapp.com gives Settings, Apps, your app, App '
          'permissions, Background autostart for MIUI 14 and Security, '
          'Permissions, Autostart for older MIUI. The mi.com FAQ title '
          'names Background autostart but the page did not load.',
    ),
    MakerStep(
      textKey: LocaleKeys.maker_guide_xiaomi_step_3,
      writtenFor: 'MIUI 12 to 14, HyperOS',
      sources: [_dontKillMyApp, _miBatterySaver],
      isConfirmed: true,
      note:
          'dontkillmyapp.com names App Battery Saver and No restriction. '
          'mi.com search text names Battery saver, Power and No '
          'restrictions for HyperOS. The menu name differs by version.',
    ),
    MakerStep(
      textKey: LocaleKeys.maker_guide_xiaomi_step_4,
      writtenFor: 'MIUI 12 to 14, HyperOS',
      sources: [_dontKillMyApp],
      isConfirmed: true,
      note:
          'dontkillmyapp.com: drag the app down in the recents tray, or '
          'long-press it and pick the padlock.',
    ),
  ],
  intents: [
    // Names taken from the AutoStarter library. No Xiaomi page states them.
    MakerIntentCandidate.component(
      package: 'com.miui.securitycenter',
      component: 'com.miui.permcenter.autostart.AutoStartManagementActivity',
      sources: [_autoStarter],
      note:
          'Named in a library for the Xiaomi, Redmi and Poco brands. The '
          'MIUI-autostart library page lists MIUI 10 to 14 as working for '
          'reading the state, which is a different call. Unconfirmed on '
          'HyperOS.',
    ),
  ],
);

const _autoStarter =
    'https://github.com/judemanutd/AutoStarter/blob/master/autostarter/src/'
    'main/java/com/judemanutd/autostarter/AutoStartPermissionHelper.kt';
