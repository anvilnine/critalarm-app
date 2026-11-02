part of 'critical_alarm_screen.dart';

/// What the ringing screen does for a screen reader, and nothing a sighted
/// user can see: it puts the reader on "I'm up", says once which topic is
/// ringing and for how long, and takes the VoiceOver magic tap.
class _RingingScreenReader extends StatefulWidget {
  const _RingingScreenReader({
    required this.state,
    required this.ackButtonKey,
    required this.announces,
    required this.onAnnounced,
    required this.child,
  });

  final CriticalAlarmState state;
  final GlobalKey ackButtonKey;

  /// False once this screen has made its announcement.
  final bool announces;
  final VoidCallback onAnnounced;
  final Widget child;

  @override
  State<_RingingScreenReader> createState() => _RingingScreenReaderState();
}

class _RingingScreenReaderState extends State<_RingingScreenReader>
    with WidgetsBindingObserver {
  /// Long enough for the reader to say "I'm up, button" first. An
  /// announcement made in the same moment as the focus move is cut off by it.
  static const _announceDelay = Duration(seconds: 1);

  /// The ringing screens in front right now. The magic tap stays armed on
  /// the phone while there is one, whichever order two screens report in.
  static final Set<Object> _inFrontScreens = <Object>{};

  late final AlarmHost _host = getIt<AlarmHost>();
  StreamSubscription<void>? _magicTaps;
  Timer? _announceTimer;
  bool _isRouteCurrent = false;
  AppLifecycleState? _lifecycle;
  bool _isInFront = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
    final cubit = context.read<CriticalAlarmCubit>();
    _magicTaps = _host.magicTaps.listen((_) {
      // The same path as the button. The cubit turns it down unless the
      // alarm is ringing and this screen is the one in front.
      unawaited(
        cubit.acknowledgeFromMagicTap(isRingingScreenInFront: _isInFront),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _greet());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // False while a sheet or another screen covers this one.
    _isRouteCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _updateInFront();
  }

  /// Control Center, the notification shade, a call and the app switcher
  /// leave the route current, so the route alone does not say the screen is
  /// in front. Anything but resumed disarms the magic tap; resumed arms it
  /// again when the route is still current.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _updateInFront();
  }

  void _updateInFront() => _setInFront(
    isRingingScreenInFront(
      isRouteCurrent: _isRouteCurrent,
      lifecycle: _lifecycle,
    ),
  );

  void _setInFront(bool isInFront) {
    if (isInFront == _isInFront) return;
    _isInFront = isInFront;
    if (isInFront) {
      _inFrontScreens.add(this);
    } else {
      _inFrontScreens.remove(this);
    }
    unawaited(_host.setMagicTapArmed(isArmed: _inFrontScreens.isNotEmpty));
  }

  /// Runs once the first ringing frame is up. Does nothing without a screen
  /// reader.
  void _greet() {
    if (!mounted || !MediaQuery.accessibleNavigationOf(context)) return;
    widget.ackButtonKey.currentContext?.findRenderObject()?.sendSemanticsEvent(
      const FocusSemanticEvent(),
    );
    if (!widget.announces) return;
    widget.onAnnounced();
    final view = View.of(context);
    final direction = Directionality.of(context);
    _announceTimer = Timer(_announceDelay, () {
      // A sheet that opened, or an app that left the front, inside the delay:
      // the announcement is dropped, never said over something else or later.
      if (!mounted || !_isInFront) return;
      final state = widget.state;
      unawaited(
        SemanticsService.sendAnnouncement(
          view,
          ringingAnnouncement(
            topic: state.topic,
            ringTime: state.ringTimeSpoken,
            openAlarms: state.openIncidents.length,
          ),
          direction,
        ),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _announceTimer?.cancel();
    unawaited(_magicTaps?.cancel());
    _setInFront(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
