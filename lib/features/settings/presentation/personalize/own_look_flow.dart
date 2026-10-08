import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_store.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_photo_import.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_look_keeper.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_style.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/settings/presentation/personalize/own_photo_crop_screen.dart';
import 'package:critalarm/features/settings/presentation/personalize/ringing_preview.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// What to tell the person for an import that failed with [code]. The
/// words never name the file.
String ownPhotoErrorText(String? code) => switch (code) {
  ImportOwnPhotoUsecase.wrongTypeCode =>
    LocaleKeys.alarm_styles_own_error_wrong_type.tr(),
  ImportOwnPhotoUsecase.tooLargeCode =>
    LocaleKeys.alarm_styles_own_error_too_large.tr(),
  ImportOwnPhotoUsecase.unreadableCode =>
    LocaleKeys.alarm_styles_own_error_unreadable.tr(),
  _ => LocaleKeys.alarm_styles_own_error_save_failed.tr(),
};

void _say(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Pick a photo, check it, frame it, keep it. True when a photo was kept.
///
/// With looks locked for certain it opens the paywall and picks nothing.
/// [select] also saves the own look as the phone's, which is what a first
/// photo is for. A change of photo leaves the phone's look alone.
///
/// The picked file is decoded once. The crop step shows that picture and
/// the kept photo is cut from it.
///
/// The system's picker puts a copy of the picked file in the app's cache.
/// Where it is gets written down before anything else is done with it,
/// and it is deleted as soon as the one decode is over, or the pick has
/// failed. If the app is killed in between, the next launch and the
/// account wipe both find the note and delete the copy.
Future<bool> addOwnPhoto(BuildContext context, {bool select = true}) async {
  final access = getIt<FeatureAccess>();
  await access.ready;
  if (!context.mounted) return false;
  if (access.decide(AppFeature.alarmScreenStyles) is FeatureLocked) {
    await openPaywallForFeature(
      context,
      AppFeature.alarmScreenStyles,
      LockSource.personalizeLook,
    );
    return false;
  }
  final picker = getIt<OwnPhotoPicker>();
  final store = getIt<OwnLookStore>();
  final usecase = getIt<ImportOwnPhotoUsecase>();
  final keeper = getIt<OwnAlarmLookKeeper>();
  PickedOwnPhoto? picked;
  try {
    picked = await picker.pickOne();
  } on Object catch (_) {
    picked = null;
  }
  if (picked == null) return false;
  OwnPhotoWorkingCopy? photo;
  String? failure;
  try {
    await store.notePending(picked.path);
    final opened = await usecase.open(picked);
    photo = opened.getOrNull();
    failure = opened.exceptionOrNull()?.message;
  } on Object catch (_) {
    failure = ImportOwnPhotoUsecase.unreadableCode;
  } finally {
    // The picked file is not read again from here on.
    try {
      await picker.discard(picked.path);
    } on Object catch (_) {}
    try {
      await store.discardPending();
    } on Object catch (_) {}
  }
  if (photo == null) {
    if (context.mounted) _say(context, ownPhotoErrorText(failure));
    return false;
  }
  final working = photo;
  try {
    if (!context.mounted) return false;
    // Kept no larger than this phone's own screen, in pixels.
    final screen = RingingPreview.screenOf(context);
    final pixels = screen.size * screen.devicePixelRatio;
    final kept = await Navigator.of(context, rootNavigator: true).push<bool>(
      OwnPhotoCropScreen.route(
        picture: working.image,
        onUse: (crop) async {
          final saved = await usecase.save(
            photo: working,
            crop: crop,
            screenWidth: pixels.width,
            screenHeight: pixels.height,
          );
          if (saved.isError()) {
            return ownPhotoErrorText(saved.exceptionOrNull()?.message);
          }
          // Decoded and held before the screen closes, so the look is
          // there to draw the moment it is picked.
          await keeper.refresh();
          return keeper.isReady
              ? null
              : LocaleKeys.alarm_styles_own_error_save_failed.tr();
        },
      ),
    );
    if (kept != true) return false;
    if (select) {
      await getIt<AlarmStyleChoices>().setDefault(AlarmStyleId.own.id);
    }
    return true;
  } finally {
    // The crop screen draws from a handle of its own, so the picture can
    // go while the screen is still fading out.
    working.dispose();
  }
}

/// What the person asked for in the own look's sheet.
enum _OwnLookAction { changePhoto, removePhoto }

/// The sheet behind the corner button on the "Yours" tile: the colour of
/// "I'm up", a new photo, or no photo.
///
/// A colour is saved the moment it is tapped, and the preview on the page
/// behind the sheet draws it. Removing the photo deletes the file, and
/// every choice that named the own look goes back to the phone's.
///
/// [canEdit] is false while the look cannot be drawn: alarm looks are
/// locked, or the photo's file is gone or broken. The sheet then offers
/// the one thing that never needs a plan, removing the photo.
Future<void> showOwnLookSheet(
  BuildContext context, {
  bool canEdit = true,
}) async {
  AppHaptics.selection();
  final action = await showAppSheet<_OwnLookAction>(
    context: context,
    title: LocaleKeys.alarm_styles_own_sheet_title.tr(),
    subtitle: LocaleKeys.alarm_styles_own_private_note.tr(),
    content: (sheetContext) => OwnLookSheetContent(canEdit: canEdit),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _OwnLookAction.changePhoto:
      await addOwnPhoto(context, select: false);
    case _OwnLookAction.removePhoto:
      await removeOwnPhoto();
  }
}

/// Deletes the own photo. Every saved choice of the own look goes with
/// it: the phone's goes back to the standard look and a topic's back to
/// the phone's, so no choice is left pointing at a photo that is gone.
Future<void> removeOwnPhoto() async {
  final choices = getIt<AlarmStyleChoices>();
  await getIt<OwnAlarmLookKeeper>().removePhoto();
  final saved = choices.assignments;
  if (saved.defaultStyleId == AlarmStyleId.own.id) {
    await choices.setDefault(null);
  }
  for (final MapEntry(key: topic, value: id) in saved.perTopic.entries) {
    if (id == AlarmStyleId.own.id) await choices.setTopicStyle(topic, null);
  }
}

/// What is inside [showOwnLookSheet]: the eight colours, a sample of the
/// button in the picked one, and the two actions on the photo.
class OwnLookSheetContent extends StatefulWidget {
  const OwnLookSheetContent({this.canEdit = true, super.key});

  /// False leaves out everything but "Remove photo".
  final bool canEdit;

  @override
  State<OwnLookSheetContent> createState() => _OwnLookSheetContentState();
}

class _OwnLookSheetContentState extends State<OwnLookSheetContent> {
  late final OwnAlarmLookKeeper _keeper = getIt<OwnAlarmLookKeeper>();
  StreamSubscription<void>? _changes;

  @override
  void initState() {
    super.initState();
    _changes = _keeper.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  Future<void> _pick(OwnLookAccent accent) async {
    AppHaptics.selection();
    await _keeper.setAccent(accent);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final picked = _keeper.accent;
    final remove = AppButton(
      label: LocaleKeys.alarm_styles_own_remove_photo.tr(),
      variant: AppButtonVariant.dangerText,
      isFullWidth: true,
      onPressed: () => Navigator.of(context).pop(_OwnLookAction.removePhoto),
    );
    if (!widget.canEdit) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [remove],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LocaleKeys.alarm_styles_own_accent_title.tr(),
          style: AppTypography.small(
            colors.ink2,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: Spacing.s2),
        Wrap(
          spacing: Spacing.s2,
          runSpacing: Spacing.s2,
          children: [
            for (final accent in ownLookAccents)
              _AccentSwatch(
                accent: accent,
                isSelected: accent.id == picked.id,
                onTap: () => unawaited(_pick(accent)),
              ),
          ],
        ),
        const SizedBox(height: Spacing.s4),
        // The button as it will be drawn, so the colour is judged as a
        // button with its label on it and not as a dot.
        ExcludeSemantics(
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: picked.fill,
              borderRadius: Radii.fullAll,
            ),
            child: Text(
              LocaleKeys.critical_alarm_acknowledge_button.tr(),
              maxLines: 1,
              style: AppTypography.small(
                picked.label,
                fontSize: 16,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: Spacing.s4),
        AppButton(
          label: LocaleKeys.alarm_styles_own_change_photo.tr(),
          variant: AppButtonVariant.ink,
          isFullWidth: true,
          onPressed: () =>
              Navigator.of(context).pop(_OwnLookAction.changePhoto),
        ),
        const SizedBox(height: Spacing.s2),
        remove,
      ],
    );
  }
}

/// One colour: a full-size target with the colour in it. The picked one
/// has an ink ring and a tick, so it reads without colour.
class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.isSelected,
    required this.onTap,
  });

  final OwnLookAccent accent;
  final bool isSelected;
  final VoidCallback onTap;

  static const double _target = 48;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      selected: isSelected,
      label: accent.nameKey.tr(),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: _target,
          height: _target,
          decoration: BoxDecoration(
            color: accent.fill,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? colors.ink : colors.hairline,
              width: isSelected ? 3 : 1,
            ),
          ),
          child: isSelected
              ? Center(
                  child: AppGlyph(
                    GlyphType.check,
                    size: 18,
                    color: accent.label,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
