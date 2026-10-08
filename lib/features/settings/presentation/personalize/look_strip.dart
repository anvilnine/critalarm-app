import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_gate.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_look_keeper.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/settings/domain/personalize/personalize_rules.dart';
import 'package:critalarm/features/settings/presentation/cubits/personalize_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/personalize_state.dart';
import 'package:critalarm/features/settings/presentation/personalize/own_look_flow.dart';
import 'package:critalarm/features/settings/presentation/personalize/personalize_chip.dart';
import 'package:critalarm/features/settings/presentation/personalize/ringing_preview.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Look section of the Personalize page.
Widget buildPersonalizeLookStrip(BuildContext context) =>
    const PersonalizeLookStrip();

/// The look being tried on the page, or null when none is.
AlarmStyle? lookTriedBy(PersonalizeState state) {
  final tried = state.tried;
  if (tried == null || tried.feature != AppFeature.alarmScreenStyles) {
    return null;
  }
  final id = AlarmStyleId.fromId(tried.optionId);
  return id == null ? null : alarmStyleOf(id);
}

/// The look the page's preview draws: the one being tried, or else the
/// one that really rings for a topic with no look of its own.
AlarmStyle lookShownBy(PersonalizeState state) =>
    lookTriedBy(state) ?? alarmStyleOf(getIt<AlarmStyleGate>().styleFor(null));

/// Every look this build has, each as a small picture of the alarm screen
/// drawn by the alarm screen's own widgets.
///
/// The tick is on the look that really rings. Open, a tap saves the look
/// as the phone's and the preview above draws it. Locked, a tap on a paid
/// look shows it in the preview as a try and saves nothing, and the tick
/// stays on the standard look. A tap on the standard look then ends the
/// try and saves nothing either, so a look saved while the plan was held
/// comes back with the plan.
///
/// The choice here is for every topic that has no look of its own. A
/// topic's own look is on its page.
///
/// After the fixed looks comes "Yours", the person's own photo. With no
/// photo that can be drawn, the tile opens the picker. With one, it is a
/// look like the others, and a small button on its corner changes the
/// photo or the colour of "I'm up".
class PersonalizeLookStrip extends StatefulWidget {
  const PersonalizeLookStrip({super.key});

  /// The height of the strip at every text size.
  static const double height =
      PersonalizeStrip.badgeRoom + _pictureHeight + _labelGap + _labelHeight;

  static const double _pictureHeight = 96;
  static const double _labelGap = 6;
  static const double _labelHeight = 20;

  @override
  State<PersonalizeLookStrip> createState() => _PersonalizeLookStripState();
}

class _PersonalizeLookStripState extends State<PersonalizeLookStrip> {
  late final FeatureAccess _access = getIt<FeatureAccess>();
  late final AlarmStyleChoices _choices = getIt<AlarmStyleChoices>();
  late final AlarmStyleGate _gate = getIt<AlarmStyleGate>();
  late final OwnAlarmLookKeeper _ownLook = getIt<OwnAlarmLookKeeper>();
  StreamSubscription<Object?>? _accessChanges;
  StreamSubscription<void>? _choiceChanges;
  StreamSubscription<void>? _ownLookChanges;

  @override
  void initState() {
    super.initState();
    _accessChanges = _access.changes
        .where((feature) => feature == AppFeature.alarmScreenStyles)
        .listen((_) => _redraw());
    _choiceChanges = _choices.changes.listen((_) => _redraw());
    _ownLookChanges = _ownLook.changes.listen((_) => _redraw());
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    unawaited(_accessChanges?.cancel());
    unawaited(_choiceChanges?.cancel());
    unawaited(_ownLookChanges?.cancel());
    super.dispose();
  }

  void _try(AlarmStyle style) => context.read<PersonalizeCubit>().tryOption(
    PersonalizeTry(AppFeature.alarmScreenStyles, optionId: style.id.id),
  );

  Future<void> _pick(AlarmStyle style) async {
    final cubit = context.read<PersonalizeCubit>();
    // Saved only once the plan is read and is not a lock. A tap that lands
    // on a lock drawn late is a try and saves nothing.
    await _access.ready;
    if (!mounted) return;
    final isLocked =
        _access.decide(AppFeature.alarmScreenStyles) is FeatureLocked;
    if (style.id.isFree) {
      cubit.clearTry();
      // Locked, the standard look is already what rings.
      if (!isLocked) await _choices.setDefault(style.id.id);
      return;
    }
    if (isLocked) {
      _try(style);
      return;
    }
    await _choices.setDefault(style.id.id);
    cubit.clearTry();
  }

  /// The "Yours" tile, after the fixed looks.
  ///
  /// With a photo held it is a look like the others, with the edit button
  /// on its corner while it is open. Locked, a tap tries it, as for every
  /// paid look. With no photo that can be drawn (none saved, or a file
  /// that is gone or broken) it offers the picker, and locked it sells.
  Widget _own(Widget Function(AlarmStyle style) option) {
    final style = _ownLook.style;
    final name = LocaleKeys.alarm_styles_own.tr();
    if (style == null) {
      return AccessLock(
        feature: AppFeature.alarmScreenStyles,
        source: LockSource.personalizeLook,
        name: name,
        badgeOverhang: PersonalizeStrip.badgeRoom,
        child: _AddOwnLook(
          key: const ValueKey('look-own-add'),
          onTap: () => unawaited(addOwnPhoto(context)),
        ),
      );
    }
    final isLocked =
        _access.decide(AppFeature.alarmScreenStyles) is FeatureLocked;
    return AccessLock(
      feature: AppFeature.alarmScreenStyles,
      source: LockSource.personalizeLook,
      name: name,
      tap: LockTap.tryIt,
      onTry: () => _try(style),
      badgeOverhang: PersonalizeStrip.badgeRoom,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          option(style),
          if (!isLocked)
            PositionedDirectional(
              end: -6,
              top: PersonalizeLookStrip._pictureHeight - _editTarget + 6,
              child: _EditOwnLook(
                key: const ValueKey('look-own-edit'),
                onTap: () => unawaited(showOwnLookSheet(context)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rings = _gate.styleFor(null);
    return BlocBuilder<PersonalizeCubit, PersonalizeState>(
      builder: (context, state) {
        final tried = lookTriedBy(state);
        _LookOption option(AlarmStyle style) => _LookOption(
          key: ValueKey('look-${style.id.id}'),
          style: style,
          isSelected: rings == style.id,
          isMarked: tried?.id == style.id && rings != style.id,
          onTap: () => unawaited(_pick(style)),
        );
        return SizedBox(
          height: PersonalizeLookStrip.height + Spacing.s1,
          // A handful of pictures, all built, so a screen reader can reach
          // the ones off the edge.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              Spacing.s4,
              PersonalizeStrip.badgeRoom,
              Spacing.s4,
              Spacing.s1,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (index, style) in alarmStyles.indexed) ...[
                  if (index > 0) const SizedBox(width: Spacing.s3),
                  if (style.id.isFree)
                    option(style)
                  else
                    AccessLock(
                      feature: AppFeature.alarmScreenStyles,
                      source: LockSource.personalizeLook,
                      name: style.nameKey.tr(),
                      tap: LockTap.tryIt,
                      onTry: () => _try(style),
                      badgeOverhang: PersonalizeStrip.badgeRoom,
                      child: option(style),
                    ),
                ],
                const SizedBox(width: Spacing.s3),
                _own(option),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The edge of the square that takes a tap on the own look's edit button.
const double _editTarget = 44;

/// The own look's edit button: a small ink disc with a pencil on the
/// corner of the picture, inside a full-size target.
class _EditOwnLook extends StatelessWidget {
  const _EditOwnLook({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      label: LocaleKeys.alarm_styles_own_edit_label.tr(),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: _editTarget,
          child: Align(
            alignment: AlignmentDirectional.bottomEnd,
            child: Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.inkFixed,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 1.5),
              ),
              child: Center(
                child: AppGlyph(
                  GlyphType.pencil,
                  size: 13,
                  color: colors.surface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Yours" tile while there is no photo to draw: the shape of a look
/// with a plus in it. A tap opens the picker.
class _AddOwnLook extends StatelessWidget {
  const _AddOwnLook({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final media = MediaQuery.of(context);
    final screen = RingingPreview.screenOf(context).size;
    const pictureHeight = PersonalizeLookStrip._pictureHeight;
    final pictureWidth = pictureHeight * screen.width / screen.height;
    final radius = BorderRadius.circular(pictureWidth * 0.14);
    return Semantics(
      button: true,
      label: LocaleKeys.alarm_styles_own.tr(),
      hint: LocaleKeys.alarm_styles_own_add_label.tr(),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: pictureWidth < _LookOption._minWidth
              ? _LookOption._minWidth
              : pictureWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: pictureWidth,
                height: pictureHeight,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: radius,
                  border: Border.all(color: colors.ink, width: 1.5),
                ),
                child: Center(
                  child: AppGlyph(GlyphType.plus, size: 22, color: colors.ink),
                ),
              ),
              const SizedBox(height: PersonalizeLookStrip._labelGap),
              SizedBox(
                height: PersonalizeLookStrip._labelHeight,
                child: MediaQuery(
                  data: media.copyWith(
                    textScaler: media.textScaler.clamp(maxScaleFactor: 1.3),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      LocaleKeys.alarm_styles_own.tr(),
                      maxLines: 1,
                      style: AppTypography.small(
                        colors.onCanvas,
                        fontSize: 12,
                      ).copyWith(fontWeight: FontWeight.w600, height: 1.15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One look: a still picture of the ringing screen in that look, and its
/// name under it. The picked one carries a tick and a solid outline, so
/// it reads without colour.
class _LookOption extends StatelessWidget {
  const _LookOption({
    required this.style,
    required this.isSelected,
    required this.isMarked,
    required this.onTap,
    super.key,
  });

  final AlarmStyle style;

  /// The look that rings: a tick and a solid outline.
  final bool isSelected;

  /// A solid outline with no tick: the look being tried.
  final bool isMarked;

  final VoidCallback onTap;

  /// The narrowest an option is, so its name has room and the tap target
  /// is a full one.
  static const double _minWidth = 72;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final media = MediaQuery.of(context);
    final screen = RingingPreview.screenOf(context).size;
    final name = style.nameKey.tr();
    final strong = isSelected || isMarked;
    const pictureHeight = PersonalizeLookStrip._pictureHeight;
    final pictureWidth = pictureHeight * screen.width / screen.height;
    final radius = BorderRadius.circular(pictureWidth * 0.14);
    return Semantics(
      button: true,
      selected: isSelected,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: pictureWidth < _minWidth ? _minWidth : pictureWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: pictureWidth,
                height: pictureHeight,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: strong ? colors.ink : colors.hairline,
                      width: strong ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: RepaintBoundary(
                      child: RingingPreview(
                        style: style,
                        fit: BoxFit.fill,
                        isStill: true,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: PersonalizeLookStrip._labelGap),
              SizedBox(
                height: PersonalizeLookStrip._labelHeight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSelected) ...[
                      AppGlyph(GlyphType.check, size: 12, color: colors.ink),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: MediaQuery(
                        // One line of this fits the room up to here.
                        data: media.copyWith(
                          textScaler: media.textScaler.clamp(
                            maxScaleFactor: 1.3,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            name,
                            maxLines: 1,
                            style:
                                AppTypography.small(
                                  colors.onCanvas,
                                  fontSize: 12,
                                ).copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.15,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
