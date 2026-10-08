/// The pages of the welcome step, in the order the user moves through them.
enum WelcomePage {
  /// A phone at night. An alert lands, and the alarm rings until it is
  /// stopped.
  rings,

  /// Three alerts of rising priority: quiet, a notification, a ring.
  priorities,

  /// A curl typed in a terminal makes a phone ring.
  curl;

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
