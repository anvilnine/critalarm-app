import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/design_system/motion.dart';
import 'package:flutter/material.dart';

/// The face, waiting, over one line that says what is going on.
///
/// Use it wherever the app is waiting on something outside itself: a server
/// answering, a message arriving, a phone starting to ring. It stands in for a
/// bare spinner, so the wait has a face and a sentence.
///
/// The face watches: its pupils drift every few seconds, and hold still with
/// animations switched off. [message] is the one status line. Pass a
/// localized string; a new one is announced to a screen reader.
class AppWaitingFace extends StatelessWidget {
  const AppWaitingFace({
    required this.message,
    this.faceSize = 96,
    this.faceState = FaceState.watching,
    this.heroTag,
    super.key,
  });

  /// The one line under the face.
  final String message;

  /// The face over the line. It watches by default. Pass another only when
  /// the wait has just ended and the line says so, such as a phone that is
  /// now ringing.
  final FaceState faceState;

  /// Width and height of the face.
  final double faceSize;

  /// Wraps the face in a `Hero` with this tag, so it flies to and from the
  /// face on the next screen. Null draws a plain face.
  final Object? heroTag;

  /// Widest the line runs before it wraps, so it stays a caption under the
  /// face rather than a paragraph across a tablet.
  static const double _maxMessageWidth = 380;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    Widget face = FaceWidget(
      state: faceState,
      size: faceSize,
      isLive: true,
    );
    if (heroTag != null) {
      face = Hero(
        tag: heroTag!,
        flightShuttleBuilder: faceFlightShuttleBuilder,
        child: face,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        face,
        const SizedBox(height: Spacing.s3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxMessageWidth),
          child: Semantics(
            liveRegion: true,
            // A new line fades in over the old one, the way a toggle row
            // swaps its subtitle, and the block grows to fit it.
            child: AnimatedSize(
              duration: context.motion(AppDurations.base),
              curve: AppCurves.easeOut,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: context.motion(AppDurations.base),
                switchInCurve: AppCurves.easeOut,
                switchOutCurve: AppCurves.easeOut,
                child: Text(
                  message,
                  key: ValueKey(message),
                  textAlign: TextAlign.center,
                  style: AppTypography.body(colors.onCanvasMuted),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
