// Off unless asked for. A plain build talks to a real server; the in-memory
// one needs --dart-define=MOCK=true.
const buildUsesMockApi = bool.fromEnvironment('MOCK');
