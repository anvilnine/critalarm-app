import 'package:critalarm/features/reliability/domain/maker/maker_family.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide.dart';
import 'package:critalarm/gen/locale_keys.g.dart';

// Oppo, with Realme and OnePlus. ColorOS 11 to 14, Realme UI, OxygenOS 12
// and up (which is built on ColorOS). Data only: a wrong step is fixed here
// and in en.json.
//
// "Confirmed" means a page listed under `sources` was read and states the
// step. Nothing below was tried on a phone. dontkillmyapp.com's Oppo page
// says it only has information for one old phone (the F1S).

const _oppoPage = 'https://dontkillmyapp.com/oppo';
const _realmePage = 'https://dontkillmyapp.com/realme';
const _oneplusPage = 'https://dontkillmyapp.com/oneplus';

const oppoGuide = MakerGuide(
  family: MakerFamily.oppo,
  nameKey: LocaleKeys.maker_guide_oppo_name,
  moreUrl: _oppoPage,
  steps: [
    MakerStep(
      textKey: LocaleKeys.maker_guide_oppo_step_1,
      writtenFor: 'ColorOS 11 to 14, OxygenOS 12 and up',
      sources: [_oppoPage],
      isConfirmed: false,
      note:
          'dontkillmyapp.com says App info, Battery usage. The route '
          'Settings, Apps, App management comes from search result text '
          'quoting third-party ColorOS 11 and 14 guides, not a page that '
          'was read.',
    ),
    MakerStep(
      textKey: LocaleKeys.maker_guide_oppo_step_2,
      writtenFor: 'Realme UI, ColorOS 11 and up',
      sources: [_realmePage, _oppoPage],
      isConfirmed: true,
      note:
          'The Realme page says Allow background activity. The Oppo page '
          'says Run in background. The label differs by version.',
    ),
    MakerStep(
      textKey: LocaleKeys.maker_guide_oppo_step_3,
      writtenFor: 'Realme UI, ColorOS 6 and up',
      sources: [_realmePage, _oppoPage],
      isConfirmed: true,
      note:
          'The Realme page says Allow auto-launch. The Oppo page says '
          'Allow Auto Start-up for ColorOS 6 and up.',
    ),
  ],
  // Under the steps, not numbered. The old step 4 held the Realme and
  // OxygenOS 11 routes in one step. `maker_guide.oppo.step_4` is no longer
  // read.
  notes: [
    MakerNote(
      textKey: LocaleKeys.maker_guide_oppo_note_versions,
      writtenFor: 'ColorOS 11 to 14, OxygenOS 12 and up',
      sources: [_oppoPage],
      isConfirmed: false,
      note:
          'The versions step 1 was written for. No page that was read '
          'gives the range.',
    ),
    MakerNote(
      textKey: LocaleKeys.maker_guide_oppo_note_realme,
      writtenFor: 'Realme UI',
      sources: [_realmePage],
      isConfirmed: true,
      note:
          'Realme page: Settings, Battery, Power saving settings, App '
          'battery management.',
    ),
    MakerNote(
      textKey: LocaleKeys.maker_guide_oppo_note_oxygen,
      writtenFor: 'OxygenOS 11 and older',
      sources: [_oneplusPage],
      isConfirmed: true,
      note:
          'OnePlus page: System settings, Battery, Battery optimization, '
          "Don't optimize. The page also says OnePlus reverts these "
          'settings at random, so the user may need to check again.',
    ),
  ],
  intents: [
    // Names taken from the AutoStarter library. The only Oppo page that
    // names a package (dontkillmyapp.com) gives com.coloros.safecenter and
    // nothing more, so the component names stay unconfirmed.
    MakerIntentCandidate.component(
      package: 'com.coloros.safecenter',
      component:
          'com.coloros.safecenter.permission.startup.'
          'StartupAppListActivity',
      sources: [_autoStarter, _oppoPage],
      note:
          'The package is on the Oppo page. The class is from a library. '
          'Unconfirmed on ColorOS 11 and later, which moved these '
          'settings into App info.',
    ),
    MakerIntentCandidate.component(
      package: 'com.coloros.safecenter',
      component: 'com.coloros.safecenter.startupapp.StartupAppListActivity',
      sources: [_autoStarter],
      note: 'Named in a library. Unconfirmed.',
    ),
    MakerIntentCandidate.component(
      package: 'com.oppo.safe',
      component: 'com.oppo.safe.permission.startup.StartupAppListActivity',
      sources: [_autoStarter],
      note:
          'Named in a library, for the older Oppo security app. '
          'Unconfirmed.',
    ),
  ],
);

const _autoStarter =
    'https://github.com/judemanutd/AutoStarter/blob/master/autostarter/src/'
    'main/java/com/judemanutd/autostarter/AutoStartPermissionHelper.kt';
