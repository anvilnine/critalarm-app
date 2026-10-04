// What a replay of setup may write. A replay is a look at the screens, so
// nothing in it reaches the phone's saved state or the server.

/// Whether the connect form keeps what the user types as a saved draft.
bool onboardingSavesFormDraft({required bool isReplay}) => !isReplay;

/// Whether the first-topic step makes a topic on the server when the user
/// confirms. A replay ends the step instead and moves on.
bool onboardingCreatesTopic({required bool isReplay}) => !isReplay;
