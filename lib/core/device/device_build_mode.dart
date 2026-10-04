// Empty unless asked for, and only ever read in a debug build.
//
// --dart-define=DEVICE_MAKER=samsung makes a debug run answer that maker in
// place of the real one, so a screen that only some makers' phones see can
// be looked at on an emulator. A store build always reads the real maker.
const buildDeviceMaker = String.fromEnvironment('DEVICE_MAKER');
