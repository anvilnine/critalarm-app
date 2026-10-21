import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';

/// Where "Ring again" leads after the steps that make the alarm louder.
enum LoudnessRetry {
  /// Back to the setup step that sends the test alarm.
  setupStep,

  /// The test ring screen, where the user picks a topic and rings it.
  testRing,
}

/// Whether the acknowledged screen asks "Loud enough?", and where "Ring
/// again" leads when it does. Null: no question.
///
/// iPhone only. An iPhone alarm rings at the Ringtone and Alerts volume,
/// which no app can read or set, so the user is the only one who can say it
/// was too quiet. Android sets the alarm volume itself.
///
/// It is asked after a test, never after a real alarm:
/// - the setup test, sent by the server or set by the phone
///   ([AckedExits.continueSetup]);
/// - the phone-only test run again after setup ([AckedExits.retest]);
/// - a test sent from the test ring screen, the one a phone update asks for
///   ([isTestIncident], read from the title the server gives every test).
///
/// The first tool alarm and the first shipped setup order are not asked.
LoudnessRetry? loudnessAskFor({
  required bool isIos,
  required AckedExits exits,
  required bool isTestIncident,
}) {
  if (!isIos) return null;
  return switch (exits) {
    AckedExits.continueSetup => LoudnessRetry.setupStep,
    AckedExits.retest => LoudnessRetry.testRing,
    AckedExits.incident => isTestIncident ? LoudnessRetry.testRing : null,
    AckedExits.firstToolAlarm ||
    AckedExits.legacyFinish ||
    AckedExits.legacyCreateTopicOrFinish => null,
  };
}
