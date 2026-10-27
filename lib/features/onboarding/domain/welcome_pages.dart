/// The pages of the welcome step, in the order the user moves through them.
enum WelcomePage {
  /// A phone at night. An alert lands, and the alarm rings until it is
  /// stopped.
  rings,

  /// A curl typed in a terminal makes a phone ring.
  curl,

  /// The home screen widgets: a count, a ringing card, the topic list.
  widgets;

  bool get isLast => index == values.length - 1;

  /// The page after this one. The last page has none, so it is itself.
  WelcomePage get next => isLast ? this : values[index + 1];

  /// The page before this one. The first page has none, so it is itself.
  WelcomePage get previous => index == 0 ? this : values[index - 1];
}

/// What the button under the welcome pages does.
enum WelcomeButton {
  /// Moves to the next page.
  next,

  /// Finishes the welcome step.
  getStarted,
}

/// The button [page] shows: Next on every page but the last.
WelcomeButton welcomeButtonFor(WelcomePage page) =>
    page.isLast ? WelcomeButton.getStarted : WelcomeButton.next;

/// The page to show once the story on [page] is over. The same page means
/// its story plays again from the start.
///
/// Until the user moves between pages by hand ([userHasMoved]: a swipe or a
/// tap on Next), each story hands on to the next page and the last page
/// stays. After that nothing moves by itself.
WelcomePage welcomePageAfterStory(
  WelcomePage page, {
  required bool userHasMoved,
}) => userHasMoved ? page : page.next;

/// Whether [page] is the one in front: the pager rests on it and is not
/// being dragged or moved. Only that page starts its story and plays haptic
/// cues. A neighbour that is half in view during a swipe stays silent.
bool welcomePageIsInFront(
  WelcomePage page, {
  required WelcomePage restingOn,
  required bool isMoving,
}) => !isMoving && page == restingOn;

/// How far a finger has to travel sideways to change the page, when the
/// pages do not follow it.
const double welcomeSwipeMinDistance = 40;

/// The page a swipe from [page] ends on when the pages do not follow the
/// finger, as with animations switched off. [moved] is how far the finger
/// went: below zero to the left, which asks for the next page. A swipe past
/// either end stays on [page].
WelcomePage welcomePageAfterSwipe(WelcomePage page, {required double moved}) {
  if (moved <= -welcomeSwipeMinDistance) return page.next;
  if (moved >= welcomeSwipeMinDistance) return page.previous;
  return page;
}

/// How far the first page has moved off the screen, from 0 (in front) to 1
/// (gone), for a pager showing [pageValue] (`PageController.page`). The same
/// number runs when the user swipes back, because the first page is always
/// the one on the left.
double welcomeFirstPageSlide(double pageValue) => pageValue.clamp(0.0, 1.0);

/// How the first page's big title, its face and its rings leave while the
/// page moves off the screen. A page moves left by its own width times the
/// slide. The shifts below are counted in page widths and are added to that
/// move, so the net travel on screen is the page's own move plus the shift.
class WelcomeWordParting {
  const WelcomeWordParting({
    required this.faceOpacity,
    required this.faceShift,
    required this.titleOpacity,
    required this.titleShift,
  });

  /// The word page at rest: everything drawn, nothing moved.
  static const rest = WelcomeWordParting(
    faceOpacity: 1,
    faceShift: 0,
    titleOpacity: 1,
    titleShift: 0,
  );

  /// How much of the face and the rings show, from 0 to 1.
  final double faceOpacity;

  /// Page widths to the right, on top of the page's own move.
  final double faceShift;

  /// How much of the big title shows, from 0 to 1.
  final double titleOpacity;

  /// Page widths to the right, on top of the page's own move.
  final double titleShift;
}

/// The face leaves first, to the right: it travels with [welcomeFaceDrift]
/// times the page's move, so it ends up further right than it started
/// while the page goes left, and it is faded out before it could be cut by
/// anything. The title holds near where it was and fades out in the first
/// part of the move, with a small drift to the left.
const double welcomeFaceDrift = 1.6;
const double welcomeTitleDrift = 0.9;
const double welcomeFaceFadeBy = 0.22;
const double welcomeTitleFadeBy = 0.4;

/// The word page's parting at [slide], from [welcomeFirstPageSlide].
WelcomeWordParting welcomeWordPartingAt(double slide) {
  final t = slide.clamp(0.0, 1.0);
  return WelcomeWordParting(
    faceOpacity: 1 - (t / welcomeFaceFadeBy).clamp(0.0, 1.0),
    faceShift: welcomeFaceDrift * t,
    titleOpacity: 1 - (t / welcomeTitleFadeBy).clamp(0.0, 1.0),
    titleShift: welcomeTitleDrift * t,
  );
}
