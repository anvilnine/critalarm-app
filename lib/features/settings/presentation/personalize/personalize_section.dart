import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/settings/presentation/personalize/challenge_strip.dart';
import 'package:critalarm/features/settings/presentation/personalize/look_strip.dart';
import 'package:critalarm/features/settings/presentation/personalize/personalize_rows.dart';
import 'package:critalarm/features/settings/presentation/personalize/sound_strip.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/widgets.dart';

/// Where a section sits on the Personalize page.
enum PersonalizeSectionKind {
  /// A titled strip of options under the preview. Picking one changes the
  /// preview.
  strip,

  /// A plain row under the divider that leaves the page.
  row,
}

/// One block of the Personalize page.
///
/// The page is this list and nothing more: to add a block, add an entry to
/// [personalizeSections]. The page draws the heading, keeps the order,
/// listens for [feature] changing, and gives the bar under the preview what
/// it needs to sell a tried option of this section.
///
/// A [builder] draws the options. It wraps anything a plan unlocks in
/// `AccessLock`, reads and changes the page through
/// `context.read<PersonalizeCubit>()`, and never decides anything about
/// plans itself:
///
/// - a free option: `clearTry()`, then save it;
/// - a locked option in a strip: `AccessLock(tap: LockTap.tryIt, onTry: ...)`
///   that calls `tryOption(PersonalizeTry(feature, optionId: ...))`;
/// - a locked row: `AccessLock` in its default sell mode.
@immutable
class PersonalizeSection {
  const PersonalizeSection({
    required this.id,
    required this.kind,
    required this.builder,
    this.titleKey,
    this.feature,
    this.lockSource,
  });

  /// A stable name, for keys and captures.
  final String id;

  final PersonalizeSectionKind kind;

  /// The `LocaleKeys` key of the heading over a strip. A row carries its
  /// own title, so it leaves this out.
  final String? titleKey;

  /// The feature whose plan unlocks the section's paid options. Null for a
  /// section with none.
  final AppFeature? feature;

  /// Where the paywall is opened from when one of the section's locked
  /// options is being tried. Needed whenever [feature] is set.
  final LockSource? lockSource;

  final WidgetBuilder builder;
}

/// The Personalize page, top to bottom. Strips first, in this order, then
/// the divider, then rows in this order.
const List<PersonalizeSection> personalizeSections = [
  PersonalizeSection(
    id: 'sound',
    kind: PersonalizeSectionKind.strip,
    titleKey: LocaleKeys.personalize_sound_title,
    feature: AppFeature.ownSounds,
    lockSource: LockSource.personalizeSound,
    builder: buildPersonalizeSoundStrip,
  ),
  PersonalizeSection(
    id: 'look',
    kind: PersonalizeSectionKind.strip,
    titleKey: LocaleKeys.alarm_styles_strip_title,
    feature: AppFeature.alarmScreenStyles,
    lockSource: LockSource.personalizeLook,
    builder: buildPersonalizeLookStrip,
  ),
  PersonalizeSection(
    id: 'challenge',
    kind: PersonalizeSectionKind.strip,
    titleKey: LocaleKeys.challenges_strip_title,
    feature: AppFeature.wakeUpChallenges,
    lockSource: LockSource.personalizeChallenge,
    builder: buildPersonalizeChallengeStrip,
  ),
  PersonalizeSection(
    id: 'widgets',
    kind: PersonalizeSectionKind.row,
    feature: AppFeature.widgets,
    lockSource: LockSource.personalizeWidgets,
    builder: buildPersonalizeWidgetsRow,
  ),
  PersonalizeSection(
    id: 'app_icon',
    kind: PersonalizeSectionKind.row,
    feature: AppFeature.appIcons,
    lockSource: LockSource.personalizeAppIcon,
    builder: buildPersonalizeAppIconRow,
  ),
];
