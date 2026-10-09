import 'dart:math' as math;
import 'dart:ui' show Color, Size;

import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/lock_tap_rule.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/foundation.dart';

// The rules of the Look page, with nothing drawn: the deck of phones, what the
// bottom action is and does, the hint line, the poses of the phones while they
// are dragged, and the colour of the page between two looks. Pure, so they are
// unit tested and the widgets only draw what they are handed.

/// The positions of the deck, in order: the fixed looks as the registry lists
/// them, then Yours, the person's own photo, last.
///
/// Yours is always a position, drawn or not, so the deck has the same length
/// whatever the phone holds.
List<AlarmStyleId> lookDeckFor(Iterable<AlarmStyleId> fixed) =>
    List.unmodifiable(
      [
        for (final id in fixed)
          if (id != AlarmStyleId.own) id,
        AlarmStyleId.own,
      ],
    );

/// The page the deck opens on: the look that rings. A look the deck does not
/// hold opens on the first page.
int initialDeckPage(List<AlarmStyleId> deck, AlarmStyleId ringing) {
  final index = deck.indexOf(ringing);
  return index < 0 ? 0 : index;
}

/// The page a drag has settled on, or the nearest one while it moves.
int centredPage(double page, int count) =>
    page.round().clamp(0, math.max(0, count - 1));

/// How much of the person's own look the phone holds.
enum OwnLookPhase {
  /// No photo is saved.
  none,

  /// A photo is saved and the look cannot be drawn: looks are locked, or the
  /// file is gone or broken.
  saved,

  /// The look is decoded and held, so it can be drawn.
  held,

  /// A photo the person framed is held in memory for this visit and saved
  /// nowhere. It is drawn like a held look, with a pencil, and the button
  /// that keeps it is the act that asks for the plan.
  tried,
}

/// The control at the bottom of the page.
enum LookControl {
  /// A status: this look is the one that rings. It does nothing.
  inUse,

  /// "Use this look".
  use,

  /// "Add your photo", on Yours with nothing to draw.
  addPhoto,
}

/// What the bottom action is for the centred look, and what its tap does.
@immutable
class LookAction {
  const LookAction({
    required this.control,
    required this.keep,
    this.badge,
    this.showsTryBar = false,
    this.showsConfirming = false,
  });

  final LookControl control;

  /// What the tap that keeps or uses the look returns: [DoIt] saves it,
  /// [OpenPaywall] sells it, [WaitForPlan] waits for the plan to be read and
  /// asks again, [Nothing] is a status.
  final LockTapAnswer keep;

  /// The plan the badge names, or null when there is no badge: the look is
  /// open, or the plan has not been read.
  final Holding? badge;

  /// Whether the try bar stands in place of the plain button: a locked look
  /// is being shown and nothing is saved.
  final bool showsTryBar;

  /// Whether the line that says a purchase is being confirmed shows.
  final bool showsConfirming;

  @override
  bool operator ==(Object other) =>
      other is LookAction &&
      other.control == control &&
      other.keep == keep &&
      other.badge == badge &&
      other.showsTryBar == showsTryBar &&
      other.showsConfirming == showsConfirming;

  @override
  int get hashCode =>
      Object.hash(control, keep, badge, showsTryBar, showsConfirming);

  @override
  String toString() =>
      'LookAction(${control.name}, $keep, badge: ${badge?.name}, '
      'tryBar: $showsTryBar, confirming: $showsConfirming)';
}

/// The bottom action for the look at [centred].
///
/// - [inUse] is the look that rings now. It is a status.
/// - [decision] is the access layer's answer for alarm looks, and
///   [isPlanRead] whether the plan has been read. Standard needs no plan, so
///   it is open whatever the answer.
/// - [own] says what Yours can show.
///
/// The tap that keeps or uses the look asks `lockTapFor` and nothing here
/// decides on its own. A locked look with the plan read shows the try bar and
/// the badge. With the plan not read there is no badge and no try bar, and
/// the tap waits. A photo tried on Yours is a look like the others: locked,
/// it shows the try bar, and keeping it reaches the paywall.
LookAction lookActionFor({
  required AlarmStyleId centred,
  required AlarmStyleId inUse,
  required FeatureDecision decision,
  required bool isPlanRead,
  required OwnLookPhase own,
}) {
  if (centred == inUse) {
    return const LookAction(control: LookControl.inUse, keep: Nothing());
  }
  final effective = centred.isFree ? const FeatureDecision.open() : decision;
  final isLocked = effective is FeatureLocked;
  final badge = isLocked && isPlanRead ? effective.offer : null;
  final keep = lockTapFor(
    decision: effective,
    isPlanRead: isPlanRead,
    hasTry: false,
    tap: LockTapKind.keep,
  );
  final isOwn = centred == AlarmStyleId.own;
  // Yours has nothing to show without a photo. Locked with a photo saved it
  // is a locked look like any other. Open with a photo that cannot be drawn
  // it offers the picker again.
  final asksForPhoto =
      isOwn &&
      (own == OwnLookPhase.none || (own == OwnLookPhase.saved && !isLocked));
  return LookAction(
    control: asksForPhoto ? LookControl.addPhoto : LookControl.use,
    // Adding a photo is a try, open to everyone: the pick, the crop and the
    // colour show the photo as the alarm, and nothing is saved until the
    // look is kept. Keeping it is the tap that can reach the paywall.
    keep: asksForPhoto
        ? lockTapFor(
            decision: effective,
            isPlanRead: isPlanRead,
            hasTry: true,
            tap: LockTapKind.tryIt,
          )
        : keep,
    badge: badge,
    showsTryBar: badge != null && !asksForPhoto,
    showsConfirming: effective is FeatureConfirming && !asksForPhoto,
  );
}

/// What the hint line under the deck says.
@immutable
class LookHint {
  const LookHint(this.key, {this.lockedCount});

  /// The translation key.
  final String key;

  /// The number to put in "{count} more", for the locked hint.
  final int? lockedCount;

  @override
  bool operator ==(Object other) =>
      other is LookHint && other.key == key && other.lockedCount == lockedCount;

  @override
  int get hashCode => Object.hash(key, lockedCount);

  @override
  String toString() => 'LookHint($key, $lockedCount)';
}

/// The hint line for the centred look, or null when there is nothing to say.
///
/// - While looks are locked and the plan is read: "5 more with Pro", counting
///   the positions that need the plan.
/// - Otherwise: no line. The deck shows that it swipes, and a try bar under
///   it already says "Not saved". A plan not read yet sells nothing.
LookHint? lookHintFor({
  required LookAction action,
  required FeatureDecision decision,
  required bool isPlanRead,
  required List<AlarmStyleId> deck,
}) {
  if (action.showsTryBar) return null;
  if (isPlanRead && decision is FeatureLocked) {
    return LookHint(
      LocaleKeys.personalize_passes_look_hint_swipe_locked,
      lockedCount: deck.where((id) => !id.isFree).length,
    );
  }
  return null;
}

/// The ground and the text of every look in the deck, and the colour of the
/// page between two of them.
///
/// At rest the page is the look's own ground and its own text. Between two
/// looks the ground is the blend of the two grounds by the page fraction,
/// following the finger, and the text is whichever of [ink] and [cream] has
/// more contrast with that blend. The own text of a look (Terminal's green)
/// would fail on the other look's ground.
@immutable
class LookFade {
  const LookFade({
    required this.grounds,
    required this.texts,
    required this.ink,
    required this.cream,
  }) : assert(grounds.length == texts.length, 'one text per ground');

  /// The ground of each look at rest, in deck order.
  final List<Color> grounds;

  /// The text on each look at rest.
  final List<Color> texts;

  /// The dark neutral the text takes between two looks.
  final Color ink;

  /// The light neutral the text takes between two looks.
  final Color cream;

  /// How close to a whole page counts as rest.
  static const double restEpsilon = 0.001;

  int get count => grounds.length;

  /// Whether [page] is on a look.
  static bool isAtRest(double page) =>
      (page - page.roundToDouble()).abs() < restEpsilon;

  /// The ground at [page]: the blend of the two grounds either side of it.
  Color groundAt(double page) {
    final clamped = page.clamp(0.0, (count - 1).toDouble());
    final low = clamped.floor();
    final high = math.min(low + 1, count - 1);
    final fraction = clamped - low;
    if (fraction < restEpsilon || low == high) return grounds[low];
    if (1 - fraction < restEpsilon) return grounds[high];
    return Color.lerp(grounds[low], grounds[high], fraction)!;
  }

  /// The text at [page]: the look's own at rest, the better neutral between.
  Color textAt(double page) {
    final clamped = page.clamp(0.0, (count - 1).toDouble());
    if (isAtRest(clamped)) return texts[clamped.round()];
    final ground = groundAt(clamped);
    return ColorContrast.contrastRatio(ink, ground) >=
            ColorContrast.contrastRatio(cream, ground)
        ? ink
        : cream;
  }
}

/// How a phone is posed, by its place in the deck and where the deck is.
@immutable
class LookPose {
  const LookPose({
    required this.scale,
    required this.opacity,
    required this.tilt,
  });

  /// 1 for the centred phone, [neighbourScale] for a neighbour.
  final double scale;

  /// 1 for the centred phone, [neighbourOpacity] for a neighbour, less
  /// further out.
  final double opacity;

  /// Degrees, positive clockwise. 0 at rest.
  final double tilt;

  @override
  bool operator ==(Object other) =>
      other is LookPose &&
      other.scale == scale &&
      other.opacity == opacity &&
      other.tilt == tilt;

  @override
  int get hashCode => Object.hash(scale, opacity, tilt);

  @override
  String toString() => 'LookPose($scale, $opacity, $tilt)';
}

/// A neighbour's scale and opacity.
const double neighbourScale = 0.77;
const double neighbourOpacity = 0.85;

/// The most a phone tilts while the deck is dragged, in degrees.
const double deckTiltMax = 5;

/// How much less opaque each further step out is, below [neighbourOpacity].
const double _opacityStepOut = 0.2;
const double _opacityFloor = 0.45;

/// The pose of the phone at [index] when the deck is at [page].
///
/// The centred phone is full size and fully opaque. Its neighbours are
/// [neighbourScale] and [neighbourOpacity], and the ones further out fade
/// by their distance. Nothing rests at an angle: a phone tilts away from the
/// centre in proportion to how far the deck is from a whole page, up to
/// [deckTiltMax], and is upright at rest.
LookPose lookPoseAt(int index, double page) {
  final offset = index - page;
  final distance = offset.abs();
  final near = math.min(distance, 1);
  final scale = 1 - (1 - neighbourScale) * near;
  final opacity = distance <= 1
      ? 1 - (1 - neighbourOpacity) * near
      : math.max(
          _opacityFloor,
          neighbourOpacity - _opacityStepOut * (distance - 1),
        );
  // 0 on a whole page, 1 half way between two.
  final drag = math.min(1, 2 * (page - page.roundToDouble()).abs());
  final side = offset.clamp(-1, 1).toDouble();
  return LookPose(
    scale: scale,
    opacity: opacity,
    tilt: isAtRestPage(page) ? 0 : deckTiltMax * side * drag,
  );
}

/// Whether [page] is on a whole page, for the poses.
bool isAtRestPage(double page) => LookFade.isAtRest(page);

/// How long the centred phone takes for one rock there and back, in seconds.
const double lookRockPeriod = 1.2;

/// How far the centred phone rocks either side of upright, in degrees.
const double lookRockDegrees = 1.5;

/// The centred phone's rock at clock [t], in degrees, positive clockwise. It
/// is 0 at t = 0, swings [lookRockDegrees] either side of upright and repeats
/// every [lookRockPeriod] seconds. With [isStill] it is the resting frame,
/// upright.
double lookRock(double t, {bool isStill = false}) {
  if (isStill) return 0;
  return lookRockDegrees * math.sin(2 * math.pi * t / lookRockPeriod);
}

/// The widest the centred phone is on a 390 wide display, in points.
const double _phoneWidthAt390 = 204;
const double _phoneRefWidth = 390;

/// The least tall the centred phone is drawn, in points.
const double _minPhoneHeight = 120;

/// The room between two phones at rest, in points.
const double _phoneGap = 24;

/// The shortest display side from which a phone in the deck is drawn at a
/// phone's own shape and not at the display's.
const double _tabletShortestSide = 600;

/// The screen a phone of the deck is laid out for.
///
/// A phone in the deck is always upright. On a display wider than tall (a
/// phone on its side, a tablet) it is laid out for the same screen turned
/// upright. A display too big to be a phone gets a phone's shape of 390 by
/// 844, so the sample text stays readable at the size the deck draws it.
Size lookScreenSize(Size display) {
  final shortest = math.min(display.width, display.height);
  final longest = math.max(display.width, display.height);
  if (shortest >= _tabletShortestSide) return const Size(390, 844);
  return Size(shortest, longest);
}

/// The least contrast an inactive dot of the deck keeps with the page.
const double lookDotMinContrast = 3;

/// The colour of the dot of a look that is [near] the middle (1 is the middle,
/// 0 is a page or more away). The middle one is [text]. The others are [text]
/// faded toward [ground] as far as the page keeps [lookDotMinContrast] with
/// them, so they stay seen on any look's ground.
Color lookDotColor({
  required Color text,
  required Color ground,
  required double near,
}) {
  var faded = text;
  for (var alpha = 0.35; alpha <= 1.0; alpha += 0.05) {
    final candidate = Color.alphaBlend(text.withValues(alpha: alpha), ground);
    if (ColorContrast.contrastRatio(candidate, ground) >= lookDotMinContrast) {
      faded = candidate;
      break;
    }
  }
  return Color.lerp(faded, text, near.clamp(0.0, 1.0))!;
}

/// The size of the centred phone.
///
/// A phone keeps the shape of this display's screen ([aspect] is width over
/// height). It is as tall as [availableHeight] lets it be, and no wider than
/// 204 points at 390 wide, scaled with a narrower column. A display wider
/// than tall (a tablet, a phone on its side) is held to a share of the column.
Size lookPhoneSize({
  required double columnWidth,
  required double availableHeight,
  required double aspect,
}) {
  final maxWidth = aspect <= 1
      ? _phoneWidthAt390 *
            math.min(columnWidth, _phoneRefWidth) /
            _phoneRefWidth
      : columnWidth * 0.56;
  final height = math.max(
    _minPhoneHeight,
    math.min(availableHeight, maxWidth / aspect),
  );
  return Size(height * aspect, height);
}

/// The distance between the centres of two phones, so the page fraction of
/// the deck is `lookPhoneStep / columnWidth`. The neighbour's near edge stays
/// [_phoneGap] clear of the centred phone's.
double lookPhoneStep(double phoneWidth) =>
    phoneWidth / 2 + phoneWidth * neighbourScale / 2 + _phoneGap;
