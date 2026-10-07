import 'package:critalarm/design/faces/face_state.dart';

/// What a face says on the reliability screens and on Home's notices.
///
/// A face means one state, wherever it is drawn. A check that is fine, or
/// does not apply to this phone, and a row that only opens another screen
/// have no face at all (a tick or nothing). The other two states each have
/// one face, and it is the face the matching header uses ("Take a look" and
/// "Fix this"). Nothing picks a face by check, by reason or by position.

/// Something may stop an alarm, and the person should look. The face of the
/// "Take a look" header, of every row that needs a look and of every Home
/// notice that asks for one.
const FaceState needsLookFace = FaceState.skeptical;

/// An alarm may not ring. The face of the "Fix this" header and of every row
/// that is broken.
const FaceState brokenFace = FaceState.sad;
