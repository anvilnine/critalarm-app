import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart' show SeverityMode;
import 'package:critalarm/features/reliability/domain/readiness_pips.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_kind.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_model.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';

/// The card for the moment setup finishes: every pip full, `3/3`, a glad
/// face and no button. The screen shows it while the setup content is in its
/// finishing phases, then the card returns to its kind.
HomeCardModel setupFinishCard() => HomeCardModel(
  kind: HomeCardKind.setup,
  label: HomeCardLabel.setup,
  numeral: const Count(3, 3),
  pips: [for (final _ in SetupChecklistRow.values) PipTone.fine],
  foot: const HomeCardFoot(HomeCardFootSlot.setupNext),
  face: FaceState.happy,
  severity: SeverityMode.none,
  discTone: HomeCardDiscTone.paleYellow,
  numeralTone: HomeCardNumeralTone.yellow,
);
