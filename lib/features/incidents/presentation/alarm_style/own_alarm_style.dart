import 'dart:ui' as ui;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_scrim.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/standard_alarm_style.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/material.dart';

// Yours: the person's own photo behind the alarm screen, under a scrim,
// and a colour of their choice on "I'm up".
//
// It is the one look whose picture the app does not make, so nothing here
// trusts the picture. The words that sit on the canvas are near white,
// and the scrim is worked out from how bright the photo was measured to
// be at import (`ownLookScrimFor`), so they read on any photo. The
// message card and the bar behind the acknowledged buttons are solid, as
// in every look. "I'm up" is a solid fill brighter than anything the
// scrim leaves, in the picked colour, and the two quiet buttons are a
// faint wash, so "I'm up" is the heaviest thing in the bar at rest and
// while the acknowledge is on its way.
//
// The same dark canvas in both themes: the photo is the screen. While
// the phone rings the card is paper in both themes too. A dark card
// would need a light second ink, the spinner in "I'm up" is drawn in that
// ink, and a busy fill dark enough for a light spinner sinks into the
// scrimmed photo. Once acknowledged there is no spinner, and the card
// follows the theme.

/// What is drawn where the photo does not reach, and what backs the
/// pinned buttons. Near black, so the scrimmed photo fades into it.
const Color _canvas = Color(0xFF0B0A09);
const Color _canvasAlt = Color(0xFF151311);

/// The words on the photo, in both themes and both stages.
const Color ownLookWords = Color(0xFFFFFBF5);

/// The alarm colour of the ringing face's extras, such as the anger vein
/// on its head. Ink, which reads on the yellow head.
const Color _faceAccent = Color(0xFF1A140F);

/// The topic pill once acknowledged. A dark tint: over the photo it can
/// only make what is behind the topic darker, never lighter.
const Color _pill = Color(0x66000000);
const Color _pillFaint = Color(0x33000000);

/// The card in the dark theme: a clear step off the near-black bar, so
/// "Back to topics" shows on it. The rows inside the details card are set
/// in, darker than the card, and the faint ink is lifted to read on both.
const Color _darkCard = Color(0xFF2A231E);
const Color _darkRow = Color(0xFF1B1612);
const Color _darkInk3 = Color(0xFFA99786);

/// The fill of "I'm up" while the acknowledge is on its way: a light
/// stone, far brighter than anything the scrim leaves of a photo, so the
/// button stays the heaviest in the bar, with a dark spinner on it.
const Color _busy = Color(0xFFCFC7BC);

/// The fill of a button that is off on the acknowledged stage in the dark
/// theme, where the inks are light. No button of that stage is off today.
const Color _darkOff = Color(0xFF8A827A);

/// How strong the wash of a quiet button is over the photo, 0 to 255:
/// `AppButtonVariant.tinted` lays the card colour on at 22 percent, and
/// while the phone rings the card is white. Rounded up.
const int ownLookWashAlpha = 57;

/// One colour "I'm up" can be filled with, and the label that reads on
/// it.
@immutable
class OwnLookAccent {
  const OwnLookAccent({
    required this.id,
    required this.nameKey,
    required this.fill,
    this.label = const Color(0xFF1A140F),
  });

  /// Saved on phones (`alarm_style_own_accent`), so a shipped id never
  /// changes.
  final String id;

  /// The `LocaleKeys` key of the colour's name.
  final String nameKey;

  final Color fill;
  final Color label;

  /// The fill under a pointer: a step toward white.
  Color get hover => Color.alphaBlend(const Color(0x33FFFFFF), fill);
}

/// The colours "I'm up" can take in the own look, in the order the picker
/// shows them. The first is the one a new look starts with: Crit's
/// yellow.
///
/// A fixed set on purpose. Every fill is light, so it is brighter than
/// the scrimmed photo whatever the photo is, and every label is checked
/// on its fill by the contrast test. A free colour picker could promise
/// neither.
const List<OwnLookAccent> ownLookAccents = [
  OwnLookAccent(
    id: 'yellow',
    nameKey: LocaleKeys.alarm_styles_own_accent_yellow,
    fill: Color(0xFFFFC93C),
  ),
  OwnLookAccent(
    id: 'paper',
    nameKey: LocaleKeys.alarm_styles_own_accent_paper,
    fill: Color(0xFFFFF7EA),
  ),
  OwnLookAccent(
    id: 'orange',
    nameKey: LocaleKeys.alarm_styles_own_accent_orange,
    fill: Color(0xFFFF9A3D),
  ),
  OwnLookAccent(
    id: 'coral',
    nameKey: LocaleKeys.alarm_styles_own_accent_coral,
    fill: Color(0xFFFF8A7A),
  ),
  OwnLookAccent(
    id: 'pink',
    nameKey: LocaleKeys.alarm_styles_own_accent_pink,
    fill: Color(0xFFFF9FCB),
  ),
  OwnLookAccent(
    id: 'lilac',
    nameKey: LocaleKeys.alarm_styles_own_accent_lilac,
    fill: Color(0xFFC9B6FF),
  ),
  OwnLookAccent(
    id: 'sky',
    nameKey: LocaleKeys.alarm_styles_own_accent_sky,
    fill: Color(0xFF7CCBFF),
  ),
  OwnLookAccent(
    id: 'mint',
    nameKey: LocaleKeys.alarm_styles_own_accent_mint,
    fill: Color(0xFF6FE3A5),
  ),
];

/// The accent saved as [id]. Nothing saved, or an id this build does not
/// know, is the first one.
OwnLookAccent ownLookAccentOf(String? id) {
  for (final accent in ownLookAccents) {
    if (accent.id == id) return accent;
  }
  return ownLookAccents.first;
}

/// The scrim for a photo measured as [measure], under this look's words.
OwnLookScrim ownLookScrimOf(OwnPhotoMeasure measure) => ownLookScrimFor(
  measure,
  wordsLuminance: ColorContrast.relativeLuminance(ownLookWords),
  washAlpha: ownLookWashAlpha,
);

/// A decoded photo, held in memory for the alarm screen.
///
/// The painter draws it for as long as it is held. Once [release]d it
/// draws nothing, and the dark canvas under it is what shows.
class OwnLookPhoto {
  OwnLookPhoto(this._image);

  ui.Image? _image;

  /// The picture, or null once it was let go.
  ui.Image? get image => _image;

  /// Lets the picture go and frees its memory.
  void release() {
    final image = _image;
    _image = null;
    image?.dispose();
  }
}

AppColors _ownColors(
  AppColors base,
  Brightness brightness,
  OwnLookAccent accent, {
  required bool isRinging,
}) {
  // Ringing, the card is paper in both themes. See the top of this file.
  final isDark = !isRinging && brightness == Brightness.dark;
  final inks = isDark ? AppColors.dark : AppColors.light;
  return base.copyWith(
    canvas: _canvas,
    canvasAlt: _canvasAlt,
    canvasGhost: _pillFaint,
    canvasGhostStrong: _pill,
    onCanvas: ownLookWords,
    onCanvasMuted: ownLookWords,
    surface: isDark ? _darkCard : AppColors.light.surface,
    cream: isDark ? _darkRow : AppColors.light.cream,
    ash: isDark ? _darkOff : _busy,
    ink: inks.ink,
    // Ringing, the spinner in "I'm up" is drawn in this on the busy fill.
    ink2: isDark ? AppColors.dark.ink : AppColors.light.ink2,
    ink3: isDark ? _darkInk3 : inks.ink3,
    highlight: accent.fill,
    highlightHover: accent.hover,
    highlightAlt: accent.hover,
    onHighlight: accent.label,
    crit: _faceAccent,
    hairline: ownLookWords.withValues(alpha: 0.18),
    focus: ownLookWords,
    focusGap: _canvas,
  );
}

/// The dark canvas with its three shapes left clear. They keep the place
/// of the standard look's shapes, so the canvas fades them out where they
/// are when this look takes over.
AmbientProfile _ownCanvas(AppColors appColors, Brightness brightness) {
  AmbientShape clear(Alignment anchor, double scale, double depth) =>
      AmbientShape(
        color: _canvas,
        opacity: 0,
        anchor: anchor,
        scale: scale,
        turns: 0,
        depth: depth,
      );
  return AmbientProfile(
    canvas: _canvas,
    surfaceOpacity: 1,
    shapes: List<AmbientShape>.unmodifiable([
      clear(const Alignment(0, -0.65), 0.54, 0.25),
      clear(const Alignment(-0.85, 0.35), 0.42, 0.55),
      clear(const Alignment(0.85, 0.70), 0.34, 0.85),
    ]),
  );
}

/// Everything the background can put behind the stage of the own look,
/// as flat colours: the bare canvas, and the darkest and the brightest
/// grey the scrim leaves of the photo. Every pixel under the scrim is
/// between those two greys, so words that read on both read on all of
/// it. The wash of a quiet button is laid over each by the contrast
/// rule, as the button lays it.
List<Color> ownLookBackdropTones(AppColors colors, OwnLookScrim scrim) => [
  colors.canvas,
  Color.fromARGB(
    255,
    scrim.darkestBehind,
    scrim.darkestBehind,
    scrim.darkestBehind,
  ),
  Color.fromARGB(
    255,
    scrim.brightestBehind,
    scrim.brightestBehind,
    scrim.brightestBehind,
  ),
];

/// The background of the own look: the photo, filling the screen, with
/// the scrim.
///
/// The scrim is not a second layer. The photo is drawn once, with every
/// value multiplied down, which is the same picture as black at the
/// scrim's strength over it. So there is no frame, and no failure, in
/// which the photo is on screen without its scrim.
///
/// Cost: one image drawn once. It never moves, so it is painted when the
/// stage is first drawn and when the photo changes, and never again. It
/// reads no file and decodes nothing: the picture it is given is already
/// in memory.
class _OwnBackdropPainter extends CustomPainter {
  _OwnBackdropPainter({required this.photo, required this.keep})
    : _image = photo.image;

  final OwnLookPhoto photo;

  /// The picture as it was when this painter was made.
  final ui.Image? _image;

  /// What every value of the photo is multiplied by, 0 to 255.
  final int keep;

  @override
  void paint(Canvas canvas, Size size) {
    final image = _image;
    // Let go since this painter was made: the dark canvas shows.
    if (image == null || !identical(photo.image, image)) return;
    if (size.isEmpty) return;
    final target = Offset.zero & size;
    final fitted = applyBoxFit(
      BoxFit.cover,
      Size(image.width.toDouble(), image.height.toDouble()),
      size,
    );
    final source = Alignment.center.inscribe(
      fitted.source,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
    );
    canvas.drawImageRect(
      image,
      source,
      target,
      Paint()
        // Never `high`: a sharper filter can overshoot, and draw a pixel
        // brighter than any the photo has. This one only averages.
        ..filterQuality = FilterQuality.medium
        ..colorFilter = ColorFilter.mode(
          Color.fromARGB(255, keep, keep, keep),
          BlendMode.modulate,
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _OwnBackdropPainter oldDelegate) =>
      !identical(oldDelegate._image, photo.image) || oldDelegate.keep != keep;
}

/// The own look, built from what the phone holds: a decoded [photo], how
/// bright it was measured to be, and the picked [accent].
///
/// The type is the standard look's, the face is the yellow one, the pulse
/// ring is left out, and the buttons keep the standard look's treatment:
/// "I'm up" filled, the two quiet buttons washed.
AlarmStyle buildOwnAlarmStyle({
  required OwnLookPhoto photo,
  required OwnPhotoMeasure measure,
  required OwnLookAccent accent,
}) {
  final scrim = ownLookScrimOf(measure);
  AppColors ringing(
    AppColors base,
    SeverityMode severity,
    Brightness brightness,
  ) => _ownColors(base, brightness, accent, isRinging: true);
  AppColors acknowledged(
    AppColors base,
    SeverityMode severity,
    Brightness brightness,
  ) => _ownColors(base, brightness, accent, isRinging: false);
  return AlarmStyle(
    id: AlarmStyleId.own,
    nameKey: LocaleKeys.alarm_styles_own,
    backdrop: (frame) => _OwnBackdropPainter(photo: photo, keep: scrim.keep),
    ringing: AlarmRingingLook(
      colors: ringing,
      ambient: _ownCanvas,
      type: standardRingingType,
      showsPulseRing: false,
      // The outline of the face is the colour of the words. The scrim is
      // built so that colour reads on everything it leaves of the photo,
      // which an ink outline does not: over a dark photo it was lost. The
      // sound waves take the same colour from `onCanvas`.
      faceOutline: ownLookWords,
      // The quiet buttons keep the standard look's wash. An outline in
      // the colour of the words would be a stronger shape than any
      // coloured fill, and "I'm up" must be the heaviest. The scrim is
      // built for the label on the wash (`ownLookWashAlpha`).
    ),
    acknowledged: AlarmAcknowledgedLook(
      colors: acknowledged,
      ambient: _ownCanvas,
      type: standardAcknowledgedType,
    ),
  );
}

AlarmStyle? _held;

/// The own look as it is held in memory right now, or null when the phone
/// has none ready: no photo saved, the file gone or broken, or the decode
/// not finished.
///
/// This is what the alarm screen reads when it rings. It is a field read
/// and nothing else: no file, no decode, no wait. Only
/// `OwnAlarmLookKeeper` sets it.
AlarmStyle? get heldOwnAlarmStyle => _held;

/// Sets or clears [heldOwnAlarmStyle].
void holdOwnAlarmStyle(AlarmStyle? style) => _held = style;
