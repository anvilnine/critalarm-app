import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/size_class.dart';

/// The item a two-pane screen shows in its detail pane, out of [items] in
/// list order.
///
/// - The person picked an item ([picked]: a tap, a link) and it is still
///   listed: that item.
/// - The picked item has gone (deleted, filtered out): null, and the pane
///   shows its empty state until the next pick.
/// - Nothing picked: [latched], the item the pane opened on, while it is
///   still listed, so a list that reorders under an untouched pane does not
///   move it. Else the first item, so the pane never opens empty.
///
/// The screen keeps what this returns as its next [latched] while nothing
/// is picked. An item opened that way is not marked read.
K? paneSelection<K>({required List<K> items, required K? picked, K? latched}) {
  if (picked != null) return items.contains(picked) ? picked : null;
  if (latched != null && items.contains(latched)) return latched;
  return items.isEmpty ? null : items.first;
}

/// True when a screen draws its hero in the scaffold's `foldStage` and leaves
/// it out of its slivers: tabletop always, book only when the screen has no
/// detail pane (with one, book puts the list in the start pane and the hero
/// stays at the top of the list). Matches where `AppScreenScaffold` draws the
/// stage.
bool heroOnFoldStage(AppFold fold, {required bool hasDetail}) =>
    fold.isTabletop || (fold.isBook && !hasDetail);

/// True when `/topics/<name>` (or a page under it) puts the topic in Home's
/// detail pane instead of a topic page of its own: an expanded window with no
/// fold, and nothing on the root navigator above the tabs
/// ([hasPageAboveShell]). With the ringing alarm (or any page that covers the
/// tabs) on top, the topic opens as its own page over it, so the alarm stays
/// where it is. Book posture opens the topic screen split at the fold, and
/// tabletop has no detail pane.
bool opensTopicInHomePane(
  AppSize size,
  AppFold fold, {
  required bool hasPageAboveShell,
}) => !hasPageAboveShell && size.isExpanded && fold.isNone;
