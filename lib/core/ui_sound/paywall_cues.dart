import 'package:critalarm/core/ui_sound/intro_sound_flavour.dart';
import 'package:critalarm/core/ui_sound/ui_sound_host.dart';
import 'package:critalarm/design_system/haptics.dart';

/// Every small moment a paywall can mark, by name.
///
/// This is the whole table: each cue is a sound and a haptic that go
/// together, and one call to [PaywallCues.play] gives both. A cue with no
/// [sound] is touch only.
///
/// None of these is an alarm. The app never makes one: an alarm comes from
/// the server. The sounds are short interface sounds made for these screens,
/// kept in their own folder so the sound picker never lists them.
enum PaywallCue {
  /// The paywall came on screen. An arrival that asks: one strike of a
  /// tine, level, left hanging. It must never sound like a reward, which
  /// is [bought]'s alone.
  open(sound: 'ui_open', haptic: HapticPattern.light),

  /// An entrance that prints, such as a till receipt.
  print(sound: 'ui_print', haptic: HapticPattern.tick),

  /// The hand moved a layout one step on.
  tick(sound: 'ui_tick', haptic: HapticPattern.tick),

  /// The yearly plan was picked.
  pickYearly(sound: 'ui_pick_yearly', haptic: HapticPattern.light),

  /// The monthly plan was picked.
  pickMonthly(sound: 'ui_pick_monthly', haptic: HapticPattern.light),

  /// The purchase is confirmed. The only celebration: mallets that climb
  /// into the app's three note call and land home.
  bought(sound: 'ui_buy', haptic: HapticPattern.risingPair),

  /// The paywall was closed without buying. A small musical sigh on a
  /// music box: one note held, a fall of a third, and a lift of a step at
  /// the very end, like a shrug. A little let down and kind about it, left
  /// open. Unlike [error], which is two low struck notes stepping down for
  /// a thing that did not work.
  close(sound: 'ui_close', haptic: HapticPattern.fallingPair),

  /// The mascot, or anything round, lands at the end of an entrance.
  pop(sound: 'ui_pop', haptic: HapticPattern.light),

  /// A heavier landing that bounces twice.
  drop(sound: 'ui_drop', haptic: HapticPattern.tripleFade),

  /// Something slides in or through. Air does not touch, so no haptic.
  whoosh(sound: 'ui_whoosh'),

  /// A sheet or a peek comes up.
  rise(sound: 'ui_rise', haptic: HapticPattern.tick),

  /// The benefit changed by itself. Quieter than [tick], which is the
  /// hand's, and with no haptic, because it keeps coming while nobody
  /// touches the screen.
  next(sound: 'ui_next'),

  /// Two tiles trade places.
  swap(sound: 'ui_swap', haptic: HapticPattern.light),

  /// A card or a tag turns over.
  flip(sound: 'ui_flip', haptic: HapticPattern.tick),

  /// A switch or a limit says no. A dull double knock.
  refuse(sound: 'ui_refuse', haptic: HapticPattern.doubleKnock),

  /// The same thing, now allowed. The bright answer to [refuse].
  lift(sound: 'ui_lift', haptic: HapticPattern.risingPair),

  /// A rubber stamp lands.
  stamp(sound: 'ui_stamp', haptic: HapticPattern.heavy),

  /// Paper tears off.
  tear(sound: 'ui_tear', haptic: HapticPattern.light),

  /// One receipt line prints. Small enough for five in a row.
  line(sound: 'ui_line', haptic: HapticPattern.tick, mayRepeat: true),

  /// A dragged divider crosses a notch. Touch only.
  ratchet(haptic: HapticPattern.tick, mayRepeat: true),

  /// A dragged thing settles.
  snap(sound: 'ui_snap', haptic: HapticPattern.medium),

  /// A story page advances.
  page(sound: 'ui_page', haptic: HapticPattern.tick),

  /// A word rolls into place.
  roll(sound: 'ui_roll', haptic: HapticPattern.tick, mayRepeat: true),

  /// A line gets its check mark.
  check(sound: 'ui_check', haptic: HapticPattern.tick, mayRepeat: true),

  /// A restore worked.
  restore(sound: 'ui_restore', haptic: HapticPattern.risingPair),

  /// A purchase failed. Soft, not a buzzer.
  error(sound: 'ui_error', haptic: HapticPattern.doubleKnock),

  /// Finger down on the main button.
  press(sound: 'ui_press', haptic: HapticPattern.medium),

  /// The last confetti comes to rest. For after the purchase cue is over.
  settle(sound: 'ui_settle', haptic: HapticPattern.tick),

  /// A padlock gives: the catch, the body, the shackle springing up.
  lock(sound: 'ui_lock', haptic: HapticPattern.medium),

  /// A key turns in a lock, or comes out of one.
  key(sound: 'ui_key', haptic: HapticPattern.light),

  /// A pull cord and the light it turns on: a click, then one warm chord.
  cord(sound: 'ui_cord', haptic: HapticPattern.risingPair),

  /// One bulb of a sign comes on. Small enough for five in a row.
  bulb(sound: 'ui_bulb', haptic: HapticPattern.tick, mayRepeat: true),

  /// An intro sting: a slow slide up and down, like a yawn.
  introSlide(sound: 'ui_intro_slide'),

  /// An intro sting: two knocks on glass.
  introKnock(sound: 'ui_intro_knock', haptic: HapticPattern.doubleKnock),

  // The scores: one short piece of music for each intro, started on its
  // first frame and timed to it. Three parts: a set up, the turn where the
  // joke lands and the music stops dead, and the arrival as the paywall
  // shows. Sound only: an intro's beats carry the haptics. Each comes in
  // every [IntroSoundFlavour]. None is an alarm sound: the set up is a soft
  // musical figure. None has the call that [bought] ends on.

  /// The score of the false alarm: a soft ringing figure, cut dead.
  scoreFalseAlarm(sound: 'ui_score_false_alarm', hasFlavours: true),

  /// The score of the snooze snack: it grows until the gulp.
  scoreSnooze(sound: 'ui_score_snooze', hasFlavours: true),

  /// The score of the rude awakening: soft and slow, then a start.
  scoreWakeUp(sound: 'ui_score_wake_up', hasFlavours: true),

  /// The score of the curtain call: a hush, a look each way.
  scoreCurtain(sound: 'ui_score_curtain', hasFlavours: true),

  /// The score of the alarm snack: the soft ringing figure with a nudge on
  /// each hop of the button, cut dead on the gulp.
  scoreAlarmSnack(sound: 'ui_score_alarm_snack', hasFlavours: true),

  /// The arrival alone, the last part of every score: a short pickup and
  /// the chord it lands on. What a skipped intro plays.
  introArrive(
    sound: 'ui_intro_arrive',
    haptic: HapticPattern.light,
    hasFlavours: true,
  );

  const PaywallCue({
    this.sound,
    this.haptic = HapticPattern.none,
    this.mayRepeat = false,
    this.hasFlavours = false,
  });

  /// The sound file's name, with no folder and no extension. Null for a cue
  /// that is touch only.
  final String? sound;

  /// The haptic that goes with the sound.
  final HapticPattern haptic;

  /// Whether the cue may come several times in quick succession. One that
  /// may is allowed to overlap itself, up to [maxVoices], so a run of them
  /// does not cut itself off. Every other cue replaces whatever is playing.
  final bool mayRepeat;

  /// Whether the cue has a file for each [IntroSoundFlavour], named with
  /// the flavour at the end.
  final bool hasFlavours;

  /// How many copies of one repeating cue may sound at once.
  static const maxVoices = 3;

  /// The Flutter asset the native player is handed, or null. A cue with
  /// flavours answers for the first of them: see [assetIn].
  String? get asset => assetIn(IntroSoundFlavour.piano);

  /// The asset played when the intro sounds are set to [flavour]. The same
  /// as [asset] for every cue that has no flavours.
  String? assetIn(IntroSoundFlavour flavour) {
    final sound = this.sound;
    if (sound == null) return null;
    final suffix = hasFlavours ? '_${flavour.name}' : '';
    return '${UiSoundHost.assetFolder}$sound$suffix.m4a';
  }

  /// How many copies of this cue may sound at once.
  int get voices => mayRepeat ? maxVoices : 1;
}

/// The cues of a paywall. A layout names a moment and gets its sound and its
/// haptic together:
///
/// ```dart
/// getIt<PaywallCues>().play(PaywallCue.stamp);
/// ```
///
/// The named methods are the same call, kept for the kit that already uses
/// them.
abstract class PaywallCues {
  const PaywallCues();

  /// Plays [cue]: its sound, if it has one, and its haptic.
  void play(PaywallCue cue);

  /// The paywall came on screen.
  void open() => play(PaywallCue.open);

  /// An entrance that prints, such as a till receipt.
  void print() => play(PaywallCue.print);

  /// One small step inside a layout's own motion.
  void tick() => play(PaywallCue.tick);

  /// A plan was picked. [yearly] says which, so the two can differ.
  void pickPlan({required bool yearly}) =>
      play(yearly ? PaywallCue.pickYearly : PaywallCue.pickMonthly);

  /// The purchase is confirmed.
  void bought() => play(PaywallCue.bought);

  /// The paywall was closed without buying.
  void close() => play(PaywallCue.close);
}

/// Which cue the frame plays when a layout appears. [rise] is for a layout
/// that comes up as a sheet. [none] is for one whose entrance is marked
/// moment by moment from its own timeline.
enum PaywallEntranceCue { open, print, rise, none }

/// Plays nothing. For the web and any platform with no player.
final class SilentPaywallCues extends PaywallCues {
  const SilentPaywallCues();

  @override
  void play(PaywallCue cue) {}
}
