import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/history/domain/entities/history_entry.dart';
import 'package:critalarm/features/topics/presentation/pane_rules.dart';

/// The incident History's detail pane shows: the one the person picked
/// ([pickedId]) while it is still listed, the newest one before anything is
/// picked, and null once the picked one has gone (a filter, a shorter plan),
/// which shows the pane's empty state.
HistoryEntry? historyPaneEntry(List<HistoryDay> days, String? pickedId) {
  final entries = [for (final day in days) ...day.entries];
  // Newest first. A stable sort keeps the list's own order for a tie.
  final byAge =
      [
        for (var i = 0; i < entries.length; i++) (i, entries[i]),
      ]..sort((a, b) {
        final age = b.$2.startedAt.compareTo(a.$2.startedAt);
        return age != 0 ? age : a.$1.compareTo(b.$1);
      });
  final id = paneSelection(
    items: [for (final (_, entry) in byAge) entry.id],
    picked: pickedId,
  );
  if (id == null) return null;
  return byAge.firstWhere((item) => item.$2.id == id).$2;
}

/// The History hero face on a display (or a fold pane) of [size]: 72 beside
/// a one-line panel on a cover screen, 60 on a phone and on anything short,
/// 120 on a tablet or a wide window.
double historyHeroFaceSize(AppSize size) {
  if (size.isCover) return 72;
  if (size.isCompact || size.isShort) return 60;
  return 120;
}
