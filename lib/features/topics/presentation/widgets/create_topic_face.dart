import 'package:critalarm/design/design.dart';

/// The face the create-topic screen wears, from what is true on it.
///
/// It asks while the form is open, turns fierce once Critical delivery is
/// on, worries at an error, and is glad when the topic exists: `success`
/// first, then `proud` once [hasSettled] says the moment has passed.
FaceState createTopicFace({
  required bool hasError,
  required bool isCreated,
  required bool hasSettled,
  required bool isCritical,
}) {
  if (isCreated) return hasSettled ? FaceState.proud : FaceState.success;
  if (hasError) return FaceState.worried;
  return isCritical ? FaceState.determined : FaceState.curious;
}
