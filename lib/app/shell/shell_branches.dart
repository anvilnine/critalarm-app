import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The branch order inside the `StatefulShellRoute` in `buildRouter`.
///
/// The tab bar and the nav rail read the same order, so a new tab means
/// changing the router, this class and [shellBranchForPath] together.
abstract final class ShellBranch {
  static const topics = 0;
  static const history = 1;
  static const settings = 2;

  /// The first location of each branch, in branch order. The router test
  /// checks these against the real route table so the two cannot drift.
  static const locations = <String>['/', '/history', '/settings'];
}

/// Which tab owns [path], or null when the path draws on the root navigator
/// and so belongs to no tab.
///
/// A null answer means pushing the path is safe from anywhere: it covers the
/// display and pops back to whatever opened it. A non-null answer that is not
/// the tab the user is on means a plain push would move the shell to that tab
/// without telling anyone, which leaves the tab bar highlighting a tab the
/// user is not looking at and swallows the next tap on it.
int? shellBranchForPath(String path) {
  final location = path.split('?').first.split('#').first;
  if (location == '/') return ShellBranch.topics;
  // A topic and its sub-screens live inside the topics tab. `/topics/new`
  // is the one full-screen route under that prefix.
  if (location.startsWith('/topics/') && location != '/topics/new') {
    return ShellBranch.topics;
  }
  if (location == '/history' || location.startsWith('/history/')) {
    return ShellBranch.history;
  }
  if (location == '/settings' || location.startsWith('/settings/')) {
    return ShellBranch.settings;
  }
  return null;
}

/// True when opening [path] while the app shows [from] has to be a `go`:
/// [path] lives on a tab and that tab is not the one [from] is on. Anything
/// else is a push. Used where there is no shell context to ask, such as a
/// notification tap or a quick action.
bool opensWithGo(String path, {required String from}) {
  final branch = shellBranchForPath(path);
  return branch != null && branch != shellBranchForPath(from);
}

/// Opens [path] from anywhere, moving the tab bar with the user when the path
/// lives on a different tab.
///
/// Same tab, or a route that covers the display, is a push: the tab keeps its
/// own back stack. A different tab is a `go`, which switches the branch on
/// purpose so `currentIndex` stays honest.
void openAppPath(BuildContext context, String path) {
  final branch = shellBranchForPath(path);
  final shell = StatefulNavigationShell.maybeOf(context);
  final router = GoRouter.of(context);

  if (branch == null || branch == shell?.currentIndex) {
    unawaited(router.push<void>(path));
    return;
  }
  router.go(path);
}
