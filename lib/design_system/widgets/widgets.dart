/// Design-system widget catalog. One import for feature code; every export
/// carries a one-line API summary. Check here before building new UI.
library;

/// Re-exports from Crit Alarm Design System.
export 'package:critalarm/design/components/components.dart';
export 'package:critalarm/design/faces/faces.dart';

/// Centralized haptics (capture/success/destructive/done/selection).
export '../haptics.dart';

/// Motion helpers: reduced-motion aware `context.motion(...)` duration.
export '../motion.dart';

/// Centered zero-data state: icon + title + message + optional CTA.
export 'empty_state.dart';

/// THE panel primitive: solid card, seam border, optional left rail.
export 'mat_panel.dart';

/// Permission explainer sheet: icon plate + display title + allow/not-now.
export 'permission_primer.dart';

/// Accent action plate with a hard offset shadow; label uppercased.
export 'primary_button.dart';

/// Horizontal filled progress track.
export 'progress_rail.dart';

/// "SHOW ALL (N)" / "SHOW LESS" reveal keeping hidden rows reachable.
export 'reveal_more.dart';

/// Titled content card on the elevated surface.
export 'section_card.dart';

/// Section title row with an optional trailing text action.
export 'section_header.dart';

/// Strip of tape: uppercase label on a solid colour block with dark ink.
export 'tape_label.dart';
