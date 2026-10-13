/// Whether the phone's own records say setup is open and only the first
/// message is missing.
///
/// It reads four flags and nothing from the server, so Home's card can be the
/// waiting card on its first frame, before the topic list has loaded. It is a
/// guess: the list may still show that no topic has Critical delivery on, and
/// the checklist then takes over.
///
/// - [hasServer]: a server URL and token are saved.
/// - [wasSetUpHere]: setup was finished or left on a build that has the Home
///   checklist. A phone set up long ago never has it.
/// - [isChecklistRetired]: the checklist finished, or was never needed.
/// - [isFirstMessageReceived]: a message from the user's own tool has come.
bool firstMessageExpected({
  required bool hasServer,
  required bool wasSetUpHere,
  required bool isChecklistRetired,
  required bool isFirstMessageReceived,
}) =>
    hasServer && wasSetUpHere && !isChecklistRetired && !isFirstMessageReceived;
