// Test/dev builds retain existing in-memory behavior; production CI passes
// --dart-define=MOCK=false explicitly.
const buildUsesMockApi = bool.fromEnvironment('MOCK', defaultValue: true);
