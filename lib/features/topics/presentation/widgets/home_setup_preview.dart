import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_setup_state.dart';
import 'package:flutter/foundation.dart';

/// A developer's look at the setup pill on Home, with made-up rows.
enum HomeSetupPreview {
  /// The one line.
  closed,

  /// Opened to the three rows.
  open,
}

/// Set from Developer options before it opens Home, and cleared when the
/// pill's own way out is used. A store build has no control that sets it,
/// and Home reads it in a developer build only.
final ValueNotifier<HomeSetupPreview?> homeSetupPreview =
    ValueNotifier<HomeSetupPreview?>(null);

/// What the preview draws: one row done, two to go. Its rows lead nowhere.
const HomeSetupState homeSetupPreviewState = HomeSetupState(
  phase: HomeSetupPhase.checklist,
  checklist: SetupChecklist(
    isVisible: true,
    hasServer: true,
    hasTopics: false,
    hasCriticalTopic: false,
    hasFirstMessage: false,
  ),
);
