import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:flutter/material.dart';

/// The two stages of the alarm screen.
enum AlarmStage {
  /// The phone rings: the face, the message, "I'm up" and the two quiet
  /// buttons.
  ringing,

  /// "I'm up" was tapped: when it rang, "At my desk" and the way out.
  acknowledged,
}

/// The colours one stage is drawn in, made from the app's own.
///
/// [base] is the palette of the theme the app is in, [severity] is the
/// incident's (always `ack` on the acknowledged stage) and [brightness] is
/// the theme's. The answer is the palette every widget on the stage reads
/// through `context.appColors`. A look changes a colour by changing the
/// slot the widget reads:
///
/// - The canvas behind the pinned buttons, and the focus gap: `canvas`,
///   `focusGap`.
/// - The stage word, the topic, the time, the acknowledged title and
///   line: `onCanvas`.
/// - The message card and the details card: `surface`. The rows inside
///   the details card: `cream`.
/// - The message title, body and source line: `ink`, `ink2`, `ink3`.
/// - A filled button (`AppButtonVariant.primary`): `highlight`, with
///   `onHighlight` for the label.
/// - An ink button (`AppButtonVariant.ink`): `ink`, with `canvas` for the
///   label.
/// - An outlined button (`AppButtonVariant.ghost`): `onCanvas`.
/// - A washed button (`AppButtonVariant.tinted`): `surface` at 22 percent,
///   with `onCanvas` for the label.
/// - "Back to topics" (`AppButtonVariant.paper`): `surface`, with `ink`
///   for the label.
/// - "I'm up" while the acknowledge is on its way, and any other filled
///   button that is off: `ash`, with `ink2` for the spinner or the label.
/// - The topic pill and the pulse ring: `canvasGhostStrong`.
/// - The ringing face: `faceFill`, `faceInk`, and `crit` for its outline
///   unless the look names one ([AlarmRingingLook.faceOutline]). The sound
///   waves beside it: `onCanvas`.
/// - The acknowledged face: `faceFill`.
///
/// The canvas itself is drawn by the stage's [AlarmStageLook.ambient]
/// profile, so the two must agree.
typedef AlarmStageColors =
    AppColors Function(
      AppColors base,
      SeverityMode severity,
      Brightness brightness,
    );

/// The canvas and its shapes for one stage, made from the app's own
/// colours (before [AlarmStageColors] retints them) and the theme's
/// brightness, the same one [AlarmStageColors] is handed.
///
/// A profile always has three shapes, because the canvas blends one
/// profile into the next shape by shape. A look with nothing behind it
/// gives three shapes at opacity 0.
typedef AlarmStageAmbient =
    AmbientProfile Function(AppColors appColors, Brightness brightness);

/// One frame of a look's background painter.
@immutable
class AlarmBackdropFrame {
  const AlarmBackdropFrame({
    required this.stage,
    required this.colors,
    required this.elapsed,
    required this.isStill,
  });

  final AlarmStage stage;

  /// The stage's colours, as the widgets over the background read them.
  final AppColors colors;

  /// How long the stage has been on screen. Zero, and it stays zero, when
  /// [isStill].
  final Duration elapsed;

  /// True under reduce motion, in a thumbnail, and for a look whose
  /// [AlarmStyle.backdropMoves] is false. The painter then draws one
  /// resting frame.
  final bool isStill;
}

/// Paints behind everything on a stage and over the canvas. It takes no
/// touch and a screen reader never sees it.
typedef AlarmBackdropPainter = CustomPainter Function(AlarmBackdropFrame frame);

/// The type of one stage: family, weight, size and line height, with no
/// colour. The screen adds the colour from the stage's palette.
///
/// Families are the three the app bundles (`AppTypography.fontDisplay`,
/// `fontBody`, `fontMono`). A look ships no font of its own.
@immutable
class AlarmRingingType {
  const AlarmRingingType({
    required this.word,
    required this.topic,
    required this.time,
    required this.messageTitle,
    required this.messageBody,
    required this.messageMeta,
  });

  /// The stage word over the topic, "Critical".
  final TextStyle word;

  /// The topic name.
  final TextStyle topic;

  /// How long the alarm has rung.
  final TextStyle time;

  /// The three lines of the message card. The layout measures these to
  /// size the face, so the card that is measured is the card that is
  /// drawn.
  final TextStyle messageTitle;
  final TextStyle messageBody;
  final TextStyle messageMeta;

  List<TextStyle> get all => [
    word,
    topic,
    time,
    messageTitle,
    messageBody,
    messageMeta,
  ];
}

/// The type of the acknowledged stage. See [AlarmRingingType].
@immutable
class AlarmAcknowledgedType {
  const AlarmAcknowledgedType({required this.title, required this.line});

  /// "Acknowledged".
  final TextStyle title;

  /// How long it rang, and the hint over "At my desk".
  final TextStyle line;

  List<TextStyle> get all => [title, line];
}

/// What both stages of a look have.
@immutable
abstract class AlarmStageLook {
  const AlarmStageLook({
    required this.colors,
    required this.ambient,
    required this.maxFace,
  });

  final AlarmStageColors colors;
  final AlarmStageAmbient ambient;

  /// The largest the face is drawn, in logical pixels. The layout still
  /// decides the size, and may make it smaller or leave it out. Infinity
  /// leaves the layout's size alone.
  final double maxFace;
}

/// The colour of the thin edge around "Silence" and "Read the full
/// message", from the stage's own colours, or null for no edge.
typedef AlarmQuietButtonEdge =
    Color? Function(AppColors colors, Brightness brightness);

/// How the ringing stage is drawn.
@immutable
class AlarmRingingLook extends AlarmStageLook {
  const AlarmRingingLook({
    required super.colors,
    required super.ambient,
    required this.type,
    this.showsPulseRing = true,
    super.maxFace = double.infinity,
    this.acknowledgeButton = AppButtonVariant.primary,
    this.quietButton = AppButtonVariant.tinted,
    this.quietButtonEdge,
    this.faceOutline,
    this.faceShape,
  });

  final AlarmRingingType type;

  /// The two rings that spread from the face. They are never drawn under
  /// reduce motion, whatever this says.
  final bool showsPulseRing;

  /// The treatment of "I'm up". A look changes how the button is filled,
  /// never its size, its place or its label. Its label must read at 4.5
  /// to 1 on its fill, and it must stand out from the canvas more than
  /// the quiet buttons do: `alarmStyleContrast` checks both.
  final AppButtonVariant acknowledgeButton;

  /// The treatment of "Silence" and "Read the full message".
  final AppButtonVariant quietButton;

  /// A thin edge around the two quiet buttons, for a look whose wash
  /// cannot be told from its canvas. Null, or an answer of null, draws
  /// none. Keep it fainter than the words: "I'm up" stays the heaviest.
  final AlarmQuietButtonEdge? quietButtonEdge;

  /// The outline of the ringing face. Null takes the stage's `crit`. A
  /// look sets it when `crit` cannot be seen on what is behind the face.
  final Color? faceOutline;

  /// Which shape of [ambient] sits behind the face, by its place in the
  /// profile, or null when none does. It is left clear when the face is
  /// not drawn. See [ambientFor].
  final int? faceShape;

  /// The canvas of the stage. With the face left out for room
  /// ([drawsFace] false) the shape behind it is left clear too, at its
  /// place, so the canvas still has three shapes to blend.
  AmbientProfile ambientFor(
    AppColors appColors,
    Brightness brightness, {
    required bool drawsFace,
  }) {
    final profile = ambient(appColors, brightness);
    final at = faceShape;
    if (drawsFace || at == null || at < 0 || at >= profile.shapes.length) {
      return profile;
    }
    final shape = profile.shapes[at];
    return AmbientProfile(
      canvas: profile.canvas,
      surfaceOpacity: profile.surfaceOpacity,
      shapes: List<AmbientShape>.unmodifiable([
        for (var i = 0; i < profile.shapes.length; i++)
          if (i == at)
            AmbientShape(
              color: shape.color,
              opacity: 0,
              anchor: shape.anchor,
              scale: shape.scale,
              turns: shape.turns,
              depth: shape.depth,
            )
          else
            profile.shapes[i],
      ]),
    );
  }
}

/// How the acknowledged stage is drawn. Its buttons keep their treatment
/// in every look ("At my desk" outlined, "Back to topics" on paper) and
/// take their colours from [colors].
@immutable
class AlarmAcknowledgedLook extends AlarmStageLook {
  const AlarmAcknowledgedLook({
    required super.colors,
    required super.ambient,
    required this.type,
    super.maxFace = double.infinity,
  });

  final AlarmAcknowledgedType type;
}

/// One look of the in-app alarm screen, as data.
///
/// A look says how the two stages are drawn. It cannot say what a button
/// does, where it is, how big it is or what it is called, and it has no
/// way to reach sound, vibration, timing, the screen reader order or the
/// server: none of those read it.
///
/// To add a look: add its id to [AlarmStyleId], build one of these, and
/// list it in `alarmStyles`. The registry test and the contrast test then
/// run over it with no edit.
@immutable
class AlarmStyle {
  const AlarmStyle({
    required this.id,
    required this.nameKey,
    required this.ringing,
    required this.acknowledged,
    this.backdrop,
    this.backdropMoves = false,
    this.keepsThemeFace = false,
  });

  final AlarmStyleId id;

  /// The `LocaleKeys` key of the look's name.
  final String nameKey;

  final AlarmRingingLook ringing;
  final AlarmAcknowledgedLook acknowledged;

  /// Painted behind both stages, over the canvas. Null paints nothing.
  final AlarmBackdropPainter? backdrop;

  /// Whether [backdrop] is painted again every frame. Under reduce motion
  /// it never is, whatever this says. A look that flashes keeps it under
  /// three flashes a second.
  final bool backdropMoves;

  /// True for a look whose face takes the theme's colours, and the dark
  /// theme's are dark. No look that ships sets it: a face is always
  /// yellow, so every look, the standard one included, draws the face in
  /// yellow with dark features in both themes, which the stage does for
  /// it.
  final bool keepsThemeFace;

  AlarmStageLook lookOf(AlarmStage stage) => switch (stage) {
    AlarmStage.ringing => ringing,
    AlarmStage.acknowledged => acknowledged,
  };

  /// The colours [stage] is drawn in: the look's own, with the face
  /// pinned to yellow unless [keepsThemeFace].
  AppColors colorsFor(
    AlarmStage stage, {
    required AppColors base,
    required SeverityMode severity,
    required Brightness brightness,
  }) {
    final colors = lookOf(stage).colors(
      base,
      stage == AlarmStage.acknowledged ? SeverityMode.ack : severity,
      brightness,
    );
    if (keepsThemeFace) return colors;
    return colors.copyWith(
      faceFill: AppColors.light.faceFill,
      faceInk: AppColors.light.faceInk,
      faceStroke: AppColors.light.faceStroke,
    );
  }

  /// The palette the acknowledged face takes its outline and features
  /// from: the light theme's, so the face is the yellow one in both
  /// themes. Only a look that [keepsThemeFace] takes the theme's.
  AppColors facePaletteFor(Brightness brightness) =>
      keepsThemeFace && brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;
}
