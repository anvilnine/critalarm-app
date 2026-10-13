import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_store.dart';

// The rules of the `use` step that need no screen: where an answer is kept,
// the word the pick event carries, which row starts picked, and how the page
// gives room when the phone is small or the text is large.

/// Keeps [use] where this run keeps answers: in memory on a replay, which
/// saves nothing, and on the phone otherwise.
///
/// A store that fails to write does not stop setup. The answer only decides
/// what the next steps start from, and a missing one reads as
/// [SetupUse.other].
Future<void> recordSetupUse(
  SetupUse use, {
  required bool isReplay,
  required SetupUseStore store,
  required SetupUseReplay replay,
}) async {
  if (isReplay) {
    replay.set(use);
    return;
  }
  try {
    await store.save(use);
  } on Object {
    // Nothing to show for it. The step goes on.
  }
}

/// The word the pick event sends: the answer's wire id, or `skipped` when
/// the user used the skip control.
String setupUseEventWord(SetupUse use, {required bool skipped}) =>
    skipped ? 'skipped' : use.wire;

/// The row that starts picked: the saved answer when the user came back to
/// the step, and none on a first visit.
SetupUse? setupUseStartsPicked({
  required bool cameBack,
  required bool isReplay,
  required SetupUseStore store,
  required SetupUseReplay replay,
}) => cameBack
    ? setupUseFor(isReplay: isReplay, store: store, replay: replay)
    : null;

/// The size of the face beside the title, in logical pixels, or 0 when it is
/// not drawn.
///
/// [textScale] is how much the system has grown the text (1 is the default)
/// and [width] the screen width. Above 1.3 the face is smaller, at 2.0 and
/// on a phone narrower than 340 it is dropped, so the title and the rows
/// keep the room.
double useStepFaceSizeFor({required double textScale, required double width}) {
  if (width < useStepNarrowWidth ||
      textScale >= useStepFaceDroppedScale - _slack) {
    return 0;
  }
  return textScale > useStepFaceShrinksAbove + _slack ? 72 : 124;
}

/// The title size the step asks for, before the fitter scales it down. A
/// phone narrower than 340 gets a smaller one.
double useStepTitleSizeFor({required double width}) =>
    width < useStepNarrowWidth ? 36 : 44;

/// The width below which the phone counts as narrow.
const double useStepNarrowWidth = 340;

/// The text scale above which the face shrinks.
const double useStepFaceShrinksAbove = 1.3;

/// The text scale from which the face is dropped.
const double useStepFaceDroppedScale = 2;

/// Room for the rounding of a scale read off a 16 point sample.
const double _slack = 0.001;
