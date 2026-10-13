import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_profile.dart';
import 'package:critalarm/gen/locale_keys.g.dart';

/// The words the alarm screen shows for the setup test in place of what the
/// server sent, or null to leave the server's own text.
///
/// The server fixes the test alarm's title and message, so the sample comes
/// from the phone. It is only for the alarm the server opened when setup
/// asked it to ring this phone ([SetupTestKind.serverSent]). The phone's own
/// test, a Settings test, the first tool alarm and every real incident keep
/// their text, and so does an answer with no sample.
///
/// [text] turns an `en.json` key into the string for the phone's language.
/// It is passed in so this rule needs no localization setup in a test.
({String title, String body})? setupSampleFor({
  required SetupTestKind kind,
  required SetupUse? use,
  required String Function(String key) text,
}) {
  if (kind != SetupTestKind.serverSent) return null;
  final key = SetupUseProfile.of(effectiveUse(use)).sampleKey;
  if (key == null) return null;
  return (
    title: text(key),
    body: text(LocaleKeys.setup_use_sample_body),
  );
}
