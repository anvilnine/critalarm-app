/// Whether Home reads its notice again when the router brings it back to
/// the front.
///
/// Home stays mounted while another tab is shown, so a change made there
/// (closing a missed alarm with "Got it" on the Reliability screen) would
/// show on Home only at its next load, resume or pull to refresh. Coming
/// back from another tab or screen reads it once.
///
/// A screen pushed over Home already reads the notice itself in
/// `didPopNext`, so [isCovered] skips the second read. Nothing is read when
/// Home was never left ([wasElsewhere] false).
bool readsNoticeOnReturn({
  required bool wasElsewhere,
  required bool isCovered,
}) => wasElsewhere && !isCovered;
