import 'package:critalarm/features/reliability/domain/maker/maker_guide.dart';

/// The pages to try for [guide], in order: its own, nearest first, then this
/// app's page in the system settings, which always comes last and is never
/// there twice. The native side tries them one by one and stops at the
/// first that resolves and opens.
List<MakerIntentCandidate> makerIntentOrder(MakerGuide guide) {
  const fallback = MakerIntentCandidate.appDetails();
  return [
    for (final intent in guide.intents)
      if (intent.kind != MakerIntentKind.appDetails) intent,
    fallback,
  ];
}

/// Whether the candidate at [openedIndex] in [tried] was the app's own page,
/// so the screen can say that the maker's page was not reachable. False for
/// no page opened (-1) and for an index outside the list.
bool openedFallbackPage(List<MakerIntentCandidate> tried, int openedIndex) =>
    openedIndex >= 0 &&
    openedIndex < tried.length &&
    tried[openedIndex].kind == MakerIntentKind.appDetails;
