import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/pro_pack/presentation/cubits/pro_pack_sheet_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/foundation.dart';

// What the Pro row and the Pro sheet show, decided without drawing. Pure, so
// it is unit tested and the widgets only draw what they are handed. Words
// are `LocaleKeys` keys, translated by the widget.

/// The weekly delivery check row on the Reliability screen.
@immutable
final class WeeklyCheckRowView {
  const WeeklyCheckRowView({
    required this.isLocked,
    required this.face,
    required this.lineKey,
    this.selfHostedLineKey,
  });

  /// Locked rows open the Pro sheet. An unlocked row draws its body.
  final bool isLocked;
  final FaceState face;

  /// The one short line of a locked row, or of the unlocked row until the
  /// check itself is built.
  final String lineKey;

  /// A second line for a locked row on a phone with a server of its own:
  /// the check covers the push relay, not that server. Said before anyone
  /// pays. Null on any other phone, and on an unlocked row, whose body
  /// says it itself.
  final String? selfHostedLineKey;

  @override
  bool operator ==(Object other) =>
      other is WeeklyCheckRowView &&
      other.isLocked == isLocked &&
      other.face == face &&
      other.lineKey == lineKey &&
      other.selfHostedLineKey == selfHostedLineKey;

  @override
  int get hashCode => Object.hash(isLocked, face, lineKey, selfHostedLineKey);
}

/// The row for an install that holds the pack, or does not. The two faces
/// are ones no other row or header on the Reliability screen uses.
///
/// [isSelfHosted] is the same fact the weekly check row has. The caller
/// hands it in. Nothing here reads it.
WeeklyCheckRowView weeklyCheckRowView({
  required bool isHeld,
  bool isSelfHosted = false,
}) => isHeld
    ? const WeeklyCheckRowView(
        isLocked: false,
        face: FaceState.confident,
        lineKey: LocaleKeys.pro_pack_weekly_ready_line,
      )
    : WeeklyCheckRowView(
        isLocked: true,
        face: FaceState.dozing,
        lineKey: LocaleKeys.pro_pack_weekly_locked_line,
        selfHostedLineKey: isSelfHosted
            ? LocaleKeys.weekly_check_self_hosted_line
            : null,
      );

/// The top of the Pro sheet for one stage.
@immutable
final class ProPackSheetView {
  const ProPackSheetView({
    required this.face,
    required this.titleKey,
    this.lineKey,
    this.isWaiting = false,
  });

  final FaceState face;
  final String titleKey;
  final String? lineKey;

  /// The app is waiting on the store or the relay, so the face watches and
  /// the title is the one status line.
  final bool isWaiting;

  @override
  bool operator ==(Object other) =>
      other is ProPackSheetView &&
      other.face == face &&
      other.titleKey == titleKey &&
      other.lineKey == lineKey &&
      other.isWaiting == isWaiting;

  @override
  int get hashCode => Object.hash(face, titleKey, lineKey, isWaiting);
}

/// A different face for each stage. No stage is worded as a failure.
///
/// The two stages that wait on the store itself (`loading`, `atStore`) say
/// they are asking or waiting for the store. The two that come after the
/// store has finished (`checking`, `checkingPaused`) say the purchase is
/// being confirmed, and only the paused one adds that the store is done.
/// They share their words on purpose: the wait is one wait, and the paused
/// stage only adds the line and a button.
ProPackSheetView proPackSheetView(ProPackSheetStage stage) => switch (stage) {
  ProPackSheetStage.loading => const ProPackSheetView(
    face: FaceState.watching,
    titleKey: LocaleKeys.pro_pack_sheet_loading,
    isWaiting: true,
  ),
  ProPackSheetStage.notOnSale => const ProPackSheetView(
    face: FaceState.sleepy,
    titleKey: LocaleKeys.pro_pack_sheet_title,
    lineKey: LocaleKeys.pro_pack_sheet_what,
  ),
  ProPackSheetStage.offers => const ProPackSheetView(
    face: FaceState.curious,
    titleKey: LocaleKeys.pro_pack_sheet_title,
    lineKey: LocaleKeys.pro_pack_sheet_what,
  ),
  ProPackSheetStage.atStore => const ProPackSheetView(
    face: FaceState.watching,
    titleKey: LocaleKeys.pro_pack_sheet_at_store,
    isWaiting: true,
  ),
  ProPackSheetStage.checking => const ProPackSheetView(
    face: FaceState.watching,
    titleKey: LocaleKeys.pro_pack_sheet_checking,
    isWaiting: true,
  ),
  ProPackSheetStage.checkingPaused => const ProPackSheetView(
    face: FaceState.thinking,
    titleKey: LocaleKeys.pro_pack_sheet_paused_title,
    lineKey: LocaleKeys.pro_pack_sheet_paused_line,
  ),
  ProPackSheetStage.held => const ProPackSheetView(
    face: FaceState.success,
    titleKey: LocaleKeys.pro_pack_sheet_held_title,
    lineKey: LocaleKeys.pro_pack_sheet_held_line,
  ),
};

/// The line under what Pro is, on a phone with a server of its own: the
/// check covers the push relay to the phone and not that server. It shows
/// on the stages that say what Pro is, which are the ones a person reads
/// before paying. Null on every other stage and every other phone.
///
/// [isSelfHosted] is handed in by whoever opened the sheet.
String? proPackSheetSelfHostedLineKey(
  ProPackSheetStage stage, {
  required bool isSelfHosted,
}) => switch (stage) {
  ProPackSheetStage.notOnSale || ProPackSheetStage.offers =>
    isSelfHosted ? LocaleKeys.weekly_check_self_hosted_line : null,
  ProPackSheetStage.loading ||
  ProPackSheetStage.atStore ||
  ProPackSheetStage.checking ||
  ProPackSheetStage.checkingPaused ||
  ProPackSheetStage.held => null,
};

/// The words for a note over the offers.
String proPackSheetNoteKey(ProPackSheetNote note) => switch (note) {
  ProPackSheetNote.storeProblem => LocaleKeys.pro_pack_sheet_store_problem,
  ProPackSheetNote.nothingToRestore =>
    LocaleKeys.pro_pack_sheet_nothing_to_restore,
};
