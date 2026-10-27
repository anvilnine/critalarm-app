// Used by tool/capture_responsive_matrix.dart. Not part of the app.
//
// The Topics and History pane rules, measured off the render tree in each
// capture and printed as `geometry` lines with PASS or FAIL:
//
// - two panes open on an item (no "No topic selected", no "No incident
//   selected"), and the incident rows stay inside the 680 detail cap
// - the History hero face is 120 on a tablet or a wide window
// - a cover screen shows two whole rows above the tab bar
// - book posture keeps the list or stage in the start pane and the detail
//   or passes in the end pane
// - tabletop keeps the hero above the fold band and the list below it
// - `/topics/<name>` on an expanded window opens Home with that topic in
//   the pane
//
// Developer tool.

import 'package:critalarm/design/components/floating_tab_bar.dart';
import 'package:critalarm/design/components/hero_scene.dart';
import 'package:critalarm/design/components/inbox_row.dart';
import 'package:critalarm/design/components/key_value_rows.dart';
import 'package:critalarm/design/components/pass_card.dart';
import 'package:critalarm/design/components/screen_scaffold.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/history/presentation/widgets/history_hero.dart';
import 'package:critalarm/features/history/presentation/widgets/history_row.dart';
import 'package:critalarm/features/topics/presentation/home_screen.dart';
import 'package:critalarm/features/topics/presentation/pane_rules.dart';
import 'package:critalarm/features/topics/presentation/topic_detail_screen.dart';
import 'package:critalarm/features/topics/presentation/widgets/topic_message_row.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fold_clearance.dart';

/// The screens these checks are for.
const Set<String> wp3Screens = {
  '04_home_face',
  '05_topics_list',
  '06_topic_detail',
  '16_home_topic_selected',
  '17_history',
  '18_history_selected',
  'wp3_topic_deep_link',
};

String _r(Rect r) =>
    '[${r.left.toStringAsFixed(1)}, ${r.top.toStringAsFixed(1)}, '
    '${r.right.toStringAsFixed(1)}, ${r.bottom.toStringAsFixed(1)}]';

String _n(double v) => v.toStringAsFixed(1);

/// Painted boxes of every [finder] match, top to bottom.
List<Rect> _painted(Finder finder) {
  final rects = <Rect>[];
  for (final element in finder.evaluate()) {
    final render = element.renderObject;
    if (render is! RenderBox) continue;
    final rect = paintedRect(render);
    if (rect != null && !rect.isEmpty) rects.add(rect);
  }
  rects.sort((a, b) => a.top.compareTo(b.top));
  return rects;
}

double _maxRight(List<Rect> rects) =>
    rects.map((r) => r.right).reduce((a, b) => a > b ? a : b);

bool _textShown(String text) => _painted(find.text(text)).isNotEmpty;

/// The PASS and FAIL lines for one capture. Each comes with true when its
/// check failed.
List<(String, bool)> wp3Measure(
  WidgetTester tester, {
  required String sizeId,
  required String screenId,
  required Size window,
  required AppSize size,
  required AppFold fold,
}) {
  if (!wp3Screens.contains(screenId)) return const [];
  final lines = <(String, bool)>[];
  void check(String text, {required bool ok}) =>
      lines.add(('${ok ? 'PASS' : 'FAIL'} wp3 $text', !ok));
  void note(String text) => lines.add(('wp3 $text', false));

  final isHistory = screenId.startsWith('17') || screenId.startsWith('18');
  final isTopic = screenId == '06_topic_detail';
  final rowType = isHistory ? HistoryRow : AppInboxRow;
  final rows = _painted(find.byType(rowType));
  final panes = _painted(find.byType(AppDetailPane));
  final paneTopics = [
    for (final e
        in find
            .descendant(
              of: find.byType(AppDetailPane),
              matching: find.byType(TopicDetailScreen),
            )
            .evaluate())
      (e.widget as TopicDetailScreen).topicName,
  ];

  // Two panes open on an item.
  final twoPane = AppScreenScaffold.showsDetailFor(size, fold);
  final isHomeOnExpanded =
      isTopic && opensTopicInHomePane(size, fold) ||
      screenId == 'wp3_topic_deep_link' && opensTopicInHomePane(size, fold);
  if (twoPane && !isTopic && screenId != 'wp3_topic_deep_link' ||
      isHomeOnExpanded) {
    final emptyTitle = isHistory
        ? LocaleKeys.history_detail_empty_title.tr()
        : LocaleKeys.home_detail_empty_title.tr();
    final shown = _textShown(emptyTitle);
    check(
      'detail pane open on an item '
      '(pane ${panes.isEmpty ? 'none' : _r(panes.first)}, '
      '"$emptyTitle" ${shown ? 'shown' : 'not shown'}'
      '${paneTopics.isEmpty ? '' : ', topic ${paneTopics.join(',')}'})',
      ok: panes.isNotEmpty && !shown,
    );
    if (isHistory) {
      final kv = _painted(
        find.descendant(
          of: find.byType(AppDetailPane),
          matching: find.byType(AppKeyValueRow),
        ),
      );
      for (final r in kv) {
        check(
          'incident row ${_r(r)} width ${_n(r.width)} <= '
          '${_n(AppSize.detailMaxWidth)}',
          ok: r.width <= AppSize.detailMaxWidth,
        );
      }
      final faces = _painted(
        find.descendant(
          of: find.byType(AppDetailPane),
          matching: find.byType(FaceWidget),
        ),
      );
      if (faces.isNotEmpty) {
        check(
          'incident face ${_n(faces.first.width)} (want 120)',
          ok: (faces.first.width - 120).abs() < 0.5,
        );
      }
    }
  }

  // The deep link lands on Home with the topic in the pane.
  if (screenId == 'wp3_topic_deep_link' || isTopic) {
    final onHome = _painted(find.byType(HomeScreen)).isNotEmpty;
    final pushed = [
      for (final e in find.byType(TopicDetailScreen).evaluate())
        if (!(e.widget as TopicDetailScreen).isPane)
          (e.widget as TopicDetailScreen).topicName,
    ];
    if (opensTopicInHomePane(size, fold)) {
      check(
        '/topics/nas-backup opens Home with nas-backup in the pane '
        '(home $onHome, pane ${paneTopics.join(',')}, '
        'pushed ${pushed.join(',')})',
        ok: onHome && paneTopics.contains('nas-backup') && pushed.isEmpty,
      );
    } else {
      note(
        '/topics/nas-backup opens the topic screen '
        '(pushed ${pushed.join(',')})',
      );
    }
  }

  // The History hero face.
  if (isHistory) {
    final heroFaces = _painted(
      find.descendant(
        of: find.byType(HistoryHero),
        matching: find.byWidgetPredicate(
          (w) => faceTypes.contains(w.runtimeType),
        ),
      ),
    );
    if (heroFaces.isNotEmpty) {
      final face = heroFaces.first.width;
      final want = switch (sizeId) {
        'ipad-11-portrait' || 'desktop-1440' || 'desktop-1920' => 120.0,
        'razr-cover' => 72.0,
        _ => null,
      };
      if (want == null) {
        note('History hero face ${_n(face)}');
      } else {
        check(
          'History hero face ${_n(face)} (want ${_n(want)})',
          ok: (face - want).abs() < 0.5,
        );
      }
    }
  }

  // A cover screen: two whole rows above the bar.
  final bars = _painted(find.byType(AppFloatingTabBar));
  if (size.isCover && bars.isNotEmpty && !isTopic) {
    final barTop = bars.first.top;
    final whole = rows.where((r) => r.bottom <= barTop).length;
    if (rows.length >= 2) {
      check(
        '$whole whole rows above the bar top ${_n(barTop)} '
        '(rows ${rows.map(_r).join(' ')})',
        ok: whole >= 2,
      );
    } else if (rows.isNotEmpty) {
      // The fixture has fewer rows than that: measure the room instead.
      final room = barTop - rows.first.top;
      final rowHeight = rows.first.height;
      check(
        'room for ${_n(room / rowHeight)} rows of ${_n(rowHeight)} from '
        '${_n(rows.first.top)} to the bar top ${_n(barTop)}',
        ok: room >= 2 * rowHeight,
      );
    }
  }

  // Book: list or stage start, detail or passes end.
  if (fold.isBook) {
    final band = fold.band;
    if (isTopic) {
      final heroes = _painted(find.byType(AppHeroScene));
      final passes = _painted(find.byType(AppPassCard));
      check(
        'face and card in the start pane '
        '(${heroes.map(_r).join(' ')}, band left ${_n(band.left)})',
        ok: heroes.isNotEmpty && heroes.every((r) => r.right <= band.left),
      );
      check(
        'passes in the end pane '
        '(${passes.isEmpty ? 'below the fold of the list' : _r(passes.first)},'
        ' band right ${_n(band.right)})',
        ok: passes.isEmpty || passes.every((r) => r.left >= band.right),
      );
    } else if (screenId != 'wp3_topic_deep_link') {
      check(
        'list in the start pane (rows right '
        '${rows.isEmpty ? '-' : _n(_maxRight(rows))}'
        ' <= band left ${_n(band.left)})',
        ok: rows.isNotEmpty && rows.every((r) => r.right <= band.left),
      );
      check(
        'detail in the end pane '
        '(${panes.isEmpty ? 'none' : _r(panes.first)}, '
        'band right ${_n(band.right)})',
        ok: panes.isNotEmpty && panes.first.left >= band.right,
      );
    }
  }

  // Tabletop: hero above the band, list below it.
  if (fold.isTabletop && screenId != 'wp3_topic_deep_link') {
    final band = fold.band;
    final heroes = isHistory
        ? _painted(find.byType(HistoryHero))
        : _painted(find.byType(AppHeroScene));
    final list = isTopic ? _painted(find.byType(TopicMessageRow)) : rows;
    final heroBottom = heroes.isEmpty
        ? double.nan
        : heroes.map((r) => r.bottom).reduce((a, b) => a > b ? a : b);
    check(
      'hero bottom ${_n(heroBottom)} <= band top ${_n(band.top)}',
      ok: heroes.isNotEmpty && heroBottom <= band.top,
    );
    check(
      'list starts at ${list.isEmpty ? '-' : _n(list.first.top)} >= '
      'band bottom ${_n(band.bottom)}',
      ok: list.isNotEmpty && list.first.top >= band.bottom,
    );
  }

  return lines;
}
