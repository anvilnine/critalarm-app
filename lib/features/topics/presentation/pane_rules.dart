import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/size_class.dart';

/// The item a two-pane screen shows in its detail pane, out of [items] in
/// list order.
///
/// - Nothing picked yet: the first item, so the pane never opens empty.
/// - The picked item is still in the list: that item.
/// - The picked item has gone (deleted, filtered out): null, and the pane
///   shows its empty state until the next pick.
///
/// [picked] is only ever what the person chose (a tap, a deep link). The
/// first item is worked out again on every build and never stored, so a
/// list that changes under an untouched pane moves the pane with it.
K? paneSelection<K>({required List<K> items, required K? picked}) {
  if (picked != null) return items.contains(picked) ? picked : null;
  return items.isEmpty ? null : items.first;
}

/// True when a screen draws its hero in the scaffold's `foldStage` and leaves
/// it out of its slivers: tabletop always, book only when the screen has no
/// detail pane (with one, book puts the list in the start pane and the hero
/// stays at the top of the list). Matches where `AppScreenScaffold` draws the
/// stage.
bool heroOnFoldStage(AppFold fold, {required bool hasDetail}) =>
    fold.isTabletop || (fold.isBook && !hasDetail);

/// True when `/topics/<name>` opens Home with that topic selected in the
/// detail pane rather than the topic screen as a page of its own: an
/// expanded window with no fold. Book posture opens the topic screen split at
/// the fold, and tabletop has no detail pane.
bool opensTopicInHomePane(AppSize size, AppFold fold) =>
    size.isExpanded && fold.isNone;
