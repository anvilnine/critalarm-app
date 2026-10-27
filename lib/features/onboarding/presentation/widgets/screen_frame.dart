import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// How a setup step or the new topic form is laid out on the display it is
/// drawn on. The screens with a stage (a face or a picture) on top and the
/// words and buttons under it share these rules.
enum ScreenFrame {
  /// One column, buttons pinned to the bottom. Phones, a phone on its side,
  /// and any window too short for the centred group.
  phone,

  /// The Razr cover screen (both sides under 500): the phone column with the
  /// face cut to 72 so the words keep their room above the buttons.
  cover,

  /// A tablet or desktop window: stage, words and buttons as one group in
  /// the 560 column, centred on the window, the buttons right under the
  /// words and 480 wide at most.
  centred,

  /// A half-open foldable held like a book: the stage in the start pane, the
  /// words and buttons in the end pane.
  book,

  /// A half-open foldable standing on its hinge: the stage in the top half,
  /// the words and the pinned buttons in the bottom half.
  tabletop;

  /// True where the stage goes in a pane of its own (the scaffold's
  /// `foldStage`) and out of the scrolling words.
  bool get splitsAtFold => this == book || this == tabletop;

  /// The frame for the display [context] is drawn on.
  static ScreenFrame of(BuildContext context) =>
      screenFrameFor(AppSize.of(context), AppFold.of(context));
}

/// The frame for a display of [size] with [fold]. The posture wins over the
/// size class: a half-open Pixel Fold is expanded, but its halves are not.
/// A window under 500 tall (a phone on its side) keeps the phone column,
/// since a centred group there would push the buttons off the screen.
ScreenFrame screenFrameFor(AppSize size, AppFold fold) {
  if (fold.isBook) return ScreenFrame.book;
  if (fold.isTabletop) return ScreenFrame.tabletop;
  if (size.isCover) return ScreenFrame.cover;
  if (!size.isCompact && !size.isShort) return ScreenFrame.centred;
  return ScreenFrame.phone;
}

/// Whether the buttons sit right under the words instead of pinned to the
/// bottom edge.
///
/// Only in the centred group and in the end pane of a book, never with the
/// keyboard up (the button then pins above it, as on a phone), and only
/// while the whole group [fits] in the view. A group taller than the view
/// would carry its button below the bottom edge, out of sight at rest.
bool actionsInlineFor(
  ScreenFrame frame, {
  required bool hasKeyboard,
  bool fits = true,
}) =>
    !hasKeyboard &&
    fits &&
    (frame == ScreenFrame.centred || frame == ScreenFrame.book);

/// The least height the centred group takes, so it sits in the middle of a
/// view [viewport] tall: what is left once the room above it ([above], the
/// top bar) and the room the list keeps under it ([below]) are taken off.
double centredGroupMinHeight({
  required double viewport,
  required double above,
  required double below,
}) => math.max(0, viewport - above - below);

/// Whether a group of [group] height, plus [gap] and the [actions] under it,
/// fits in [available].
bool groupFits({
  required double group,
  required double actions,
  required double gap,
  required double available,
}) => group + gap + actions <= available + 0.5;

/// The room under the last sliver of an [AppScreenScaffold] with no pinned
/// bottom bar: the home indicator and 16.
double scaffoldListFoot(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + 16;

/// A sliver that centres [child] in what is left of the view, top to bottom,
/// on a screen with no pinned bottom bar. Taller than the view, it scrolls
/// like any other sliver.
///
/// [onAvailable] hears the height the group has to fit in, after layout.
class CentredGroupSliver extends StatelessWidget {
  const CentredGroupSliver({
    required this.child,
    this.isCentred = true,
    this.onAvailable,
    super.key,
  });

  final Widget child;

  /// False keeps the same tree but drops the centring, so a field in
  /// [child] keeps its focus while the keyboard comes and goes.
  final bool isCentred;

  final ValueChanged<double>? onAvailable;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final available = centredGroupMinHeight(
          viewport: constraints.viewportMainAxisExtent,
          above: constraints.precedingScrollExtent,
          below: scaffoldListFoot(context),
        );
        final onAvailable = this.onAvailable;
        if (onAvailable != null) {
          SchedulerBinding.instance.addPostFrameCallback(
            (_) => onAvailable(available),
          );
        }
        return SliverToBoxAdapter(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: isCentred ? available : 0,
            ),
            child: Align(
              alignment: isCentred ? Alignment.center : Alignment.topCenter,
              heightFactor: 1,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// The pinned buttons, or the same buttons right under the words, at most
/// [AppSize.actionMaxWidth] wide and centred.
class InlineActions extends StatelessWidget {
  const InlineActions({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSize.actionMaxWidth),
      child: child,
    ),
  );
}

/// Reports its child's size after every layout that changed it, once the
/// frame is done. The screens read it to decide whether their group fits.
class ReportSize extends SingleChildRenderObjectWidget {
  const ReportSize({required this.onSize, super.child, super.key});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReportSize(onSize);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderReportSize).onSize = onSize;
  }
}

class _RenderReportSize extends RenderProxyBox {
  _RenderReportSize(this.onSize);

  ValueChanged<Size> onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    final now = size;
    if (now == _last) return;
    _last = now;
    SchedulerBinding.instance.addPostFrameCallback((_) => onSize(now));
  }
}

/// What a screen hands the scaffold as its `foldStage`: [child] centred in
/// its pane, at the pane's width. When the pane is too short for it (a large
/// text size in a tabletop half) it scales down rather than run into the
/// fold.
class FoldStageBox extends StatelessWidget {
  const FoldStageBox({required this.child, this.top = 0, super.key});

  final Widget child;

  /// Room kept clear at the top of the pane, for the setup tracker that the
  /// shell draws there on a step with no top bar of its own.
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top),
    child: LayoutBuilder(
      builder: (context, box) => Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          // The pane's width, so a row inside has a width to fill, and the
          // child at its own size in the middle of it.
          child: SizedBox(
            width: box.maxWidth,
            child: Center(child: child),
          ),
        ),
      ),
    ),
  );
}
