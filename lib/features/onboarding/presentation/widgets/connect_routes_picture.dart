import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_routes.dart';
import 'package:critalarm/features/onboarding/domain/setup_layout_rules.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_state.dart';
import 'package:critalarm/features/onboarding/presentation/setup_text_scale.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// The routes picture as the connect step shows it: it reads the step's
/// [state] and follows it.
///
/// Continue with Crit Alarm Cloud hands the connect to [background] and the
/// step moves on at once, without a change in [state]. So a connect that is
/// pending there counts as connecting here, and the dot runs to the phone
/// while the step leaves.
class ConnectStepRoutes extends StatelessWidget {
  const ConnectStepRoutes({
    required this.state,
    this.background,
    this.isHeader = false,
    super.key,
  });

  final OnboardingConnectState state;
  final BackgroundConnect? background;

  /// True where the picture sits over a title in place of a face. See
  /// [ConnectRoutesHeader].
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final connect = background;
    return StreamBuilder<BackgroundConnectState>(
      stream: connect?.stream,
      initialData: connect?.state,
      builder: (context, pending) {
        final view = connectRoutesFor(
          isSelfHosting: state.isSelfHosting,
          isConnecting:
              state.isConnecting ||
              (!state.isSelfHosting && (pending.data?.isPending ?? false)),
          isConnected: state.isConnected,
          hasFailed: state.status == OnboardingConnectStatus.failure,
        );
        return isHeader
            ? ConnectRoutesHeader(view: view)
            : ConnectRoutesPicture(view: view);
      },
    );
  }
}

/// The routes picture over a title, in the place of a face. It has a height
/// of its own, and goes away where the face would: when the system text is
/// large on a short screen.
class ConnectRoutesHeader extends StatelessWidget {
  const ConnectRoutesHeader({required this.view, super.key});

  final ConnectRoutesView view;

  static const double _height = 148;

  @override
  Widget build(BuildContext context) {
    if (setupFaceSizeOf(context) == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.s4),
      child: SizedBox(
        height: _height,
        child: ConnectRoutesPicture(view: view),
      ),
    );
  }
}

/// Two routes drawn at once: the user's tool to Crit Alarm Cloud to their
/// phone, and their tool to their own server to their phone.
///
/// The route in [view] is lit and the other is dim. One dot travels along
/// the lit route while it waits or connects. A connected route is drawn
/// whole and still, and a broken one stops at the server. The dot is the one
/// thing that moves, and with animations switched off it is not drawn.
class ConnectRoutesPicture extends StatefulWidget {
  const ConnectRoutesPicture({required this.view, super.key});

  final ConnectRoutesView view;

  @override
  State<ConnectRoutesPicture> createState() => _ConnectRoutesPictureState();
}

class _ConnectRoutesPictureState extends State<ConnectRoutesPicture>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// Seconds since the ticker started.
  double _now = 0;

  /// When the lit route last changed, on the ticker's clock. The dot starts
  /// over from the tool then.
  double _litAt = 0;

  /// How long the dot's first run takes after the last change.
  double _firstRunTakes = routeDotTravelTakes;

  /// True from the moment a connect starts until the dot first reaches the
  /// phone, which the phone answers with a light tap.
  bool _owesTap = false;

  /// Seconds since the lit route last changed. The painter repaints on it.
  final ValueNotifier<double> _sinceLit = ValueNotifier(0);

  bool _isStill = false;
  ModalRoute<Object?>? _route;

  bool get _hasDot => !_isStill && connectRouteHasDot(widget.view.status);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  void _onTick(Duration elapsed) {
    final before = _sinceLit.value;
    _now = elapsed.inMicroseconds / 1e6;
    final since = _now - _litAt;
    _sinceLit.value = since;
    if (_owesTap &&
        routeDotFirstArrivedBetween(
          before,
          since,
          firstRunTakes: _firstRunTakes,
        )) {
      _owesTap = false;
      final lifecycle = SchedulerBinding.instance.lifecycleState;
      final isInFront =
          (_route?.isCurrent ?? true) &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed);
      if (isInFront) AppHaptics.lightTap();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isStill = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _route = ModalRoute.of(context);
    _syncTicker();
  }

  @override
  void didUpdateWidget(ConnectRoutesPicture old) {
    super.didUpdateWidget(old);
    if (old.view == widget.view) return;
    final hasJustStarted =
        widget.view.status == ConnectRouteStatus.connecting &&
        old.view.status != ConnectRouteStatus.connecting;
    _litAt = _now;
    _sinceLit.value = 0;
    _firstRunTakes = hasJustStarted
        ? routeDotChosenRunTakes
        : routeDotTravelTakes;
    _owesTap = hasJustStarted;
    _syncTicker();
  }

  /// The ticker runs only while there is a dot to move. Stopped, not just
  /// ignored: a frame callback that does nothing still wakes the engine.
  void _syncTicker() {
    if (_hasDot && !_ticker.isActive) {
      // A ticker counts from zero each time it starts.
      _now = 0;
      _litAt = 0;
      _sinceLit.value = 0;
      unawaited(_ticker.start());
    } else if (!_hasDot && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sinceLit.dispose();
    super.dispose();
  }

  String get _label {
    final route = switch (widget.view.lit) {
      ConnectRoute.cloud => LocaleKeys.onboarding_connect_routes_label_cloud,
      ConnectRoute.ownServer => LocaleKeys.onboarding_connect_routes_label_own,
    }.tr();
    final status = switch (widget.view.status) {
      ConnectRouteStatus.waiting => null,
      ConnectRouteStatus.connecting =>
        LocaleKeys.onboarding_connect_routes_label_connecting,
      ConnectRouteStatus.connected =>
        LocaleKeys.onboarding_connect_routes_label_connected,
      ConnectRouteStatus.broken =>
        LocaleKeys.onboarding_connect_routes_label_broken,
    }?.tr();
    return status == null ? route : '$status $route';
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final fade = context.motion(AppDurations.base);
    return Semantics(
      container: true,
      image: true,
      label: _label,
      child: ExcludeSemantics(
        // A drawing, so it keeps its size when the system text grows.
        child: MediaQuery.withNoTextScaling(
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: view.lit == ConnectRoute.ownServer ? 1 : 0),
            duration: fade,
            curve: AppCurves.easeOut,
            builder: (context, own, _) => TweenAnimationBuilder<double>(
              tween: Tween(
                end: view.status == ConnectRouteStatus.connected ? 1 : 0,
              ),
              duration: fade,
              curve: AppCurves.easeOut,
              builder: (context, connected, _) => _NoIntrinsicSize(
                child: LayoutBuilder(
                  builder: (context, box) =>
                      _draw(context, box, own, connected),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const Color _panel = Color(0xFF1C1917);
  static const Color _lockScreen = Color(0xFF14121C);
  static const Color _white = Color(0xFFFFFFFF);

  /// The height of one label line, and the room between it and its node.
  static const double _labelHeight = 17;
  static const double _labelGap = 5;

  /// [own] is how far the lit route has moved from Cloud (0) to the user's
  /// own server (1), and [connected] how far it is drawn as connected.
  Widget _draw(
    BuildContext context,
    BoxConstraints box,
    double own,
    double connected,
  ) {
    final w = box.maxWidth;
    final h = box.maxHeight;
    // Too little room for it to read: it goes.
    if (!introHeroFits(h) || !w.isFinite) return const SizedBox.shrink();

    final colors = context.appColors;
    final isBroken = widget.view.status == ConnectRouteStatus.broken;

    // Two servers one above the other, each with its name on the outside,
    // the tool at the left and the phone at the right, both half way down.
    const labels = 2 * (_labelHeight + _labelGap);
    final tile = ((h - labels) * 0.3).clamp(34.0, 56.0);
    final between = (h - labels - 2 * tile).clamp(18.0, tile * 1.5);
    final top = (h - labels - 2 * tile - between) / 2;
    final cloudY = top + _labelHeight + _labelGap + tile / 2;
    final ownY = cloudY + tile + between;
    final midY = (cloudY + ownY) / 2;
    final phoneW = tile * 0.78;
    final phoneH = tile * 1.5;
    final toolX = tile / 2 + 10;
    final phoneX = w - phoneW / 2 - 14;
    final serverX = (toolX + phoneX) / 2;

    final geometry = _RoutesGeometry(
      tool: Offset(toolX + tile / 2 + 6, midY),
      phone: Offset(phoneX - phoneW / 2 - 6, midY),
      serverX: serverX,
      serverHalf: tile / 2 + 6,
      cloudY: cloudY,
      ownY: ownY,
    );

    Widget label(String text, Offset centre, double lit, {bool above = false}) {
      const width = 132.0;
      return Positioned(
        left: centre.dx - width / 2,
        width: width,
        top: above ? centre.dy - _labelHeight : centre.dy,
        height: _labelHeight,
        child: Opacity(
          opacity: 0.45 + 0.55 * lit,
          child: Text(
            text,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.visible,
            softWrap: false,
            style: AppTypography.small(
              colors.onCanvas,
              fontSize: 12,
            ).copyWith(fontWeight: FontWeight.w700, height: 1.3),
          ),
        ),
      );
    }

    Widget server(IconData icon, double y, double lit) {
      final marked = isBroken && lit > 0.5;
      return Positioned(
        left: serverX - tile / 2,
        top: y - tile / 2,
        width: tile,
        height: tile,
        child: Opacity(
          opacity: 0.45 + 0.55 * lit,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(tile * 0.3),
                    border: Border.all(
                      color: Color.lerp(
                        colors.hairline,
                        colors.cobalt,
                        connected * lit,
                      )!,
                      width: 1 + connected * lit,
                    ),
                  ),
                  child: Icon(icon, size: tile * 0.5, color: colors.ink),
                ),
              ),
              if (marked)
                Positioned(
                  right: -7,
                  top: -7,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: colors.onCanvas,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.canvas, width: 2),
                    ),
                    child: Icon(
                      Icons.priority_high,
                      size: 12,
                      color: colors.canvas,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final mono = AppTypography.monoBold(_white, fontSize: tile * 0.3);
    final toolNode = Positioned(
      left: toolX - tile / 2,
      top: midY - tile / 2,
      width: tile,
      height: tile,
      // The terminal of the How it rings story, as a tile.
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(tile * 0.3),
          border: Border.all(color: _white.withValues(alpha: 0.14)),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                r'$', // l10n-ok: a shell prompt
                style: mono.copyWith(color: colors.yellow, height: 1),
              ),
              SizedBox(width: tile * 0.08),
              Container(
                width: tile * 0.14,
                height: tile * 0.3,
                color: colors.yellow,
              ),
            ],
          ),
        ),
      ),
    );

    final phoneNode = Positioned(
      left: phoneX - phoneW / 2,
      top: midY - phoneH / 2,
      width: phoneW,
      height: phoneH,
      // The phone of the stories, small: the same body, a lock screen, and
      // the acknowledged colour once the route is connected.
      child: Container(
        padding: EdgeInsets.all(tile * 0.06),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(phoneW * 0.3),
          border: Border.all(color: _white.withValues(alpha: 0.14)),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(_lockScreen, colors.cobalt, connected),
            borderRadius: BorderRadius.circular(phoneW * 0.22),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: phoneH * 0.07,
                child: Opacity(
                  opacity: 1 - connected,
                  child: Container(
                    width: phoneW * 0.3,
                    height: phoneH * 0.055,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E0E10),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: connected,
                child: Icon(Icons.check, size: phoneW * 0.6, color: _white),
              ),
            ],
          ),
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _RoutesPainter(
              geometry: geometry,
              own: own,
              connected: connected,
              isBroken: isBroken,
              ink: colors.onCanvas,
              cobalt: colors.cobalt,
              canvas: colors.canvas,
              sinceLit: _hasDot ? _sinceLit : null,
              firstRunTakes: _firstRunTakes,
            ),
          ),
        ),
        toolNode,
        server(Icons.cloud_outlined, cloudY, 1 - own),
        server(Icons.dns_outlined, ownY, own),
        phoneNode,
        label(
          LocaleKeys.onboarding_connect_cloud_title.tr(),
          Offset(serverX, cloudY - tile / 2 - _labelGap),
          1 - own,
          above: true,
        ),
        label(
          LocaleKeys.onboarding_connect_self_host_title.tr(),
          Offset(serverX, ownY + tile / 2 + _labelGap),
          own,
        ),
        label(
          LocaleKeys.onboarding_connect_routes_tool.tr(),
          Offset(toolX, midY + tile / 2 + _labelGap),
          1,
        ),
        label(
          LocaleKeys.onboarding_connect_routes_phone.tr(),
          Offset(phoneX, midY + phoneH / 2 + _labelGap),
          1,
        ),
      ],
    );
  }
}

/// Answers "how big do you want to be" with nothing, so a scroll view that
/// asks (SliverFillRemaining does) never reaches the LayoutBuilder inside,
/// which cannot answer. The picture fills whatever room it is given anyway.
class _NoIntrinsicSize extends SingleChildRenderObjectWidget {
  const _NoIntrinsicSize({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderNoIntrinsicSize();
}

class _RenderNoIntrinsicSize extends RenderProxyBox {
  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0;
}

/// Where the two routes run, in the picture's own coordinates.
@immutable
class _RoutesGeometry {
  const _RoutesGeometry({
    required this.tool,
    required this.phone,
    required this.serverX,
    required this.serverHalf,
    required this.cloudY,
    required this.ownY,
  });

  /// Where both routes leave the tool, and where both reach the phone.
  final Offset tool;
  final Offset phone;

  /// The middle of both servers, and half a server's width plus the room a
  /// line keeps from it.
  final double serverX;
  final double serverHalf;
  final double cloudY;
  final double ownY;

  /// The line from the tool to the server at [y].
  Path legIn(double y) {
    final end = Offset(serverX - serverHalf, y);
    final bend = (end.dx - tool.dx) * 0.55;
    return Path()
      ..moveTo(tool.dx, tool.dy)
      ..cubicTo(tool.dx + bend, tool.dy, end.dx - bend, y, end.dx, y);
  }

  /// The line from the server at [y] to the phone.
  Path legOut(double y) {
    final start = Offset(serverX + serverHalf, y);
    final bend = (phone.dx - start.dx) * 0.55;
    return Path()
      ..moveTo(start.dx, y)
      ..cubicTo(
        start.dx + bend,
        y,
        phone.dx - bend,
        phone.dy,
        phone.dx,
        phone.dy,
      );
  }

  @override
  bool operator ==(Object other) =>
      other is _RoutesGeometry &&
      tool == other.tool &&
      phone == other.phone &&
      serverX == other.serverX &&
      serverHalf == other.serverHalf &&
      cloudY == other.cloudY &&
      ownY == other.ownY;

  @override
  int get hashCode =>
      Object.hash(tool, phone, serverX, serverHalf, cloudY, ownY);
}

class _RoutesPainter extends CustomPainter {
  _RoutesPainter({
    required this.geometry,
    required this.own,
    required this.connected,
    required this.isBroken,
    required this.ink,
    required this.cobalt,
    required this.canvas,
    required this.sinceLit,
    required this.firstRunTakes,
  }) : super(repaint: sinceLit);

  final _RoutesGeometry geometry;
  final double own;
  final double connected;
  final bool isBroken;
  final Color ink;
  final Color cobalt;
  final Color canvas;

  /// Seconds since the route was lit, or null when no dot is drawn.
  final ValueNotifier<double>? sinceLit;
  final double firstRunTakes;

  @override
  void paint(Canvas canvas, Size size) {
    _route(canvas, geometry.cloudY, 1 - own);
    _route(canvas, geometry.ownY, own);

    final since = sinceLit?.value;
    if (since == null) return;
    final progress = routeDotProgressAt(since, firstRunTakes: firstRunTakes);
    if (progress == null) return;
    final y = own > 0.5 ? geometry.ownY : geometry.cloudY;
    // One line from the tool, through the server, to the phone. The server
    // is drawn over it, so the dot goes in one side and out the other.
    final whole = geometry.legIn(y)
      ..lineTo(geometry.serverX + geometry.serverHalf, y)
      ..addPath(geometry.legOut(y), Offset.zero);
    final metrics = whole.computeMetrics().toList();
    final length = metrics.fold<double>(0, (sum, m) => sum + m.length);
    var left = Curves.easeInOut.transform(progress) * length;
    for (final metric in metrics) {
      if (left > metric.length) {
        left -= metric.length;
        continue;
      }
      final where = metric.getTangentForOffset(left);
      if (where == null) return;
      canvas
        ..drawCircle(where.position, 8, Paint()..color = this.canvas)
        ..drawCircle(where.position, 6, Paint()..color = cobalt);
      return;
    }
  }

  /// One route, [lit] from 0 (dim and dashed) to 1 (a whole line).
  void _route(Canvas canvas, double y, double lit) {
    final legIn = geometry.legIn(y);
    final legOut = geometry.legOut(y);
    final stopsAtServer = isBroken && lit > 0.5;

    final dashed = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = ink.withValues(alpha: 0.28);
    final solid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(ink, cobalt, connected)!.withValues(alpha: lit);

    void dash(Path path) {
      for (final metric in path.computeMetrics()) {
        for (var at = 0.0; at < metric.length; at += 10) {
          canvas.drawPath(
            metric.extractPath(at, math.min(at + 4, metric.length)),
            dashed,
          );
        }
      }
    }

    // The dashes sit under the whole line and show where it is not drawn.
    if (lit < 1) dash(legIn);
    if (lit > 0) canvas.drawPath(legIn, solid);
    if (stopsAtServer) {
      dash(legOut);
    } else {
      if (lit < 1) dash(legOut);
      if (lit > 0) canvas.drawPath(legOut, solid);
    }
  }

  @override
  bool shouldRepaint(_RoutesPainter old) =>
      old.geometry != geometry ||
      old.own != own ||
      old.connected != connected ||
      old.isBroken != isBroken ||
      old.ink != ink ||
      old.cobalt != cobalt ||
      old.canvas != canvas ||
      old.sinceLit != sinceLit ||
      old.firstRunTakes != firstRunTakes;
}
