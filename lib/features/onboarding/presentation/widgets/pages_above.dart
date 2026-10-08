import 'package:flutter/widgets.dart';

/// The page [context] is on, then the page that holds that page's
/// navigator, and so on up to the root navigator.
///
/// A setup step sits on a page of the shell's own navigator. A sheet or a
/// dialog shown on the root navigator covers the step without covering that
/// page, so the step's own page still says it is on top. The page further
/// up, the one the shell is on, is the one that hears about it.
///
/// Read this in `didChangeDependencies` and keep it, then ask
/// [isOnTopOfAll] whenever the answer is needed.
List<ModalRoute<Object?>> pagesAbove(BuildContext context) {
  final pages = <ModalRoute<Object?>>[];
  var page = ModalRoute.of(context);
  while (page != null) {
    pages.add(page);
    final navigator = page.navigator;
    page = navigator == null ? null : ModalRoute.of(navigator.context);
  }
  return pages;
}

/// Whether nothing covers any of [pages]: no page, sheet or dialog is on
/// top, on any navigator from the step's own up to the root. True when
/// there are no pages at all, as in a test with no navigator.
bool isOnTopOfAll(List<ModalRoute<Object?>> pages) =>
    pages.every((page) => page.isCurrent);
