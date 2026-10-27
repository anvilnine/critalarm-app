// The Settings split rules, read off the render tree for
// tool/capture_responsive_matrix.dart. Not part of the app.
//
// Each check comes back as a line for the run log and true when it failed,
// the same shape as the matrix's own geometry lines.

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/settings/presentation/personalize/personalize_screen.dart';
import 'package:critalarm/features/settings/presentation/server_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/settings_readiness_card.dart';
import 'package:critalarm/features/settings/presentation/sound_picker_screen.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fold_clearance.dart';

/// The screens these checks read.
const Set<String> settingsCheckScreens = {
  '10_settings',
  '14_server_disconnected',
  'wp4_settings_tap_server',
  'wp4_settings_tap_personalize',
};

/// The tallest the readiness card may be on a cover screen.
const double settingsCoverCardMaxHeight = 72;

String _r(Rect r) =>
    '[${r.left.toStringAsFixed(1)}, ${r.top.toStringAsFixed(1)}, '
    '${r.right.toStringAsFixed(1)}, ${r.bottom.toStringAsFixed(1)}]';

(String, bool) _check(bool ok, String line) =>
    ('${ok ? 'PASS' : 'FAIL'} $line', !ok);

Rect? _painted(Finder finder) {
  for (final element in finder.evaluate()) {
    final render = element.renderObject;
    if (render is! RenderBox) continue;
    final rect = paintedRect(render);
    if (rect != null) return rect;
  }
  return null;
}

Finder _inPane(Finder matching) =>
    find.descendant(of: find.byType(AppDetailPane), matching: matching);

/// A back control inside the detail pane: a back glyph button or a pass
/// back ring.
Finder _backInPane() => _inPane(
  find.byWidgetPredicate(
    (w) =>
        (w is AppIconButton && w.glyph == GlyphType.back) || w is PassBackRing,
  ),
);

/// The Settings rules at rest, before any tap. [location] is the location
/// of the route on top.
List<(String, bool)> settingsChecksAtRest(
  WidgetTester tester, {
  required String screenId,
  required AppSize size,
  required AppFold fold,
  required String location,
}) {
  if (!settingsCheckScreens.contains(screenId)) return const [];
  final lines = <(String, bool)>[];
  final card = _painted(find.byType(SettingsReadinessCard));
  final pane = _painted(find.byType(AppDetailPane));
  lines.add((
    'settings card ${card == null ? 'none' : _r(card)}, '
        'detail pane ${pane == null ? 'none' : _r(pane)}, at $location',
    false,
  ));

  if (AppScreenScaffold.showsDetailFor(size, fold)) {
    lines
      ..add(_check(pane != null, 'Settings shows a detail pane'))
      ..add(
        _check(
          _inPane(find.byType(SoundPickerScreen)).evaluate().isNotEmpty,
          'the pane opens on the first row (Default sound)',
        ),
      )
      ..add(
        _check(
          _backInPane().evaluate().isEmpty,
          'no back button in the pane',
        ),
      );
    if (card != null && pane != null) {
      lines.add(
        _check(
          card.right <= pane.left,
          'readiness card in the list pane, right ${card.right} '
          '<= pane left ${pane.left}',
        ),
      );
    }
  } else {
    lines.add(_check(pane == null, 'one pane, no detail'));
  }

  if (size.isCover && card != null) {
    lines.add(
      _check(
        card.height <= settingsCoverCardMaxHeight,
        'cover readiness card ${card.height.toStringAsFixed(1)} tall '
        '(at most $settingsCoverCardMaxHeight)',
      ),
    );
  }
  if (fold.isTabletop && card != null) {
    lines.add(
      _check(
        card.bottom <= fold.band.top,
        'readiness card bottom ${card.bottom} <= band top ${fold.band.top}',
      ),
    );
    final row = _painted(find.byType(AppListRow).first);
    if (row != null) {
      lines.add(
        _check(
          row.top >= fold.band.bottom,
          'first row top ${row.top} >= band bottom ${fold.band.bottom}',
        ),
      );
    }
  }
  if (fold.isBook && card != null) {
    lines.add(
      _check(
        card.right <= fold.band.left,
        'readiness card right ${card.right} <= band left ${fold.band.left}',
      ),
    );
  }
  return lines;
}

/// The page each tap capture opens: its widget type, its words in the log
/// and the route it pushes where there is no pane.
const Map<String, (Type, String, String)> _tapTargets = {
  'wp4_settings_tap_server': (
    ServerSettingsScreen,
    'server page',
    '/settings/server',
  ),
  'wp4_settings_tap_personalize': (
    PersonalizeScreen,
    'Personalize page',
    '/settings/personalize',
  ),
};

/// The rules after the tap on a row.
List<(String, bool)> settingsChecksAfterTap(
  WidgetTester tester, {
  required String screenId,
  required AppSize size,
  required AppFold fold,
  required String location,
}) {
  final target = _tapTargets[screenId];
  if (target == null) return const [];
  final (type, name, pushed) = target;
  final page = find.byType(type);
  if (AppScreenScaffold.showsDetailFor(size, fold)) {
    return [
      _check(
        _inPane(page).evaluate().isNotEmpty,
        'after the tap the $name is in the pane',
      ),
      _check(_backInPane().evaluate().isEmpty, 'no back button in the pane'),
      _check(
        location == '/settings',
        'top route unchanged after the tap ($location)',
      ),
    ];
  }
  return [
    _check(
      page.evaluate().isNotEmpty &&
          find.byType(AppDetailPane).evaluate().isEmpty,
      'after the tap the $name is pushed, no pane',
    ),
    _check(location == pushed, 'top route is the pushed page ($location)'),
  ];
}
