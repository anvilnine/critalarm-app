import 'package:critalarm/design/ambient/ambient_scope.dart';
import 'package:critalarm/design/components/hero_scene.dart';
import 'package:critalarm/design/components/inbox_row.dart';
import 'package:critalarm/design/components/notice_card.dart';
import 'package:critalarm/design/components/readiness_pips.dart';
import 'package:critalarm/design/components/stat_card.dart';
import 'package:critalarm/design/components/status_card.dart';
import 'package:critalarm/design/components/switches.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/theme/severity.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

// The pieces the status screens are drawn with, each with demo data. Every
// section is its own widget so the capture tool can draw one at a time. The
// words are made up for the gallery.

/// The six sections, one after another.
class TopicsComponentsSection extends StatelessWidget {
  const TopicsComponentsSection({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    key: ValueKey('gallery-topics-components'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      StatusCardsGallery(),
      SizedBox(height: 48),
      ReadinessPipsGallery(),
      SizedBox(height: 48),
      HeroSceneGallery(),
      SizedBox(height: 48),
      InboxRowsGallery(),
      SizedBox(height: 48),
      CreamCardGallery(),
      SizedBox(height: 48),
      StatCardGallery(),
    ],
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.note);

  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.headline(colors.onCanvas)),
          const SizedBox(height: Spacing.s2),
          Text(note, style: AppTypography.body(colors.onCanvasMuted)),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Spacing.s1),
    child: Text(
      text,
      style: AppTypography.mono(
        context.appColors.onCanvasMuted,
        fontSize: 11,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// The cards.
// ---------------------------------------------------------------------------

/// One kind of card with everything a hero scene needs to draw it.
class _Kind {
  const _Kind({
    required this.name,
    required this.card,
    this.severity = SeverityMode.none,
    this.face = FaceState.calm,
    this.tone = AppHeroTone.calm,
    this.gaze = AppHeroGaze.none,
    this.isLive = false,
  });

  final String name;
  final AppStatusCard card;
  final SeverityMode severity;
  final FaceState face;
  final AppHeroTone tone;
  final AppHeroGaze gaze;
  final bool isLive;
}

void _noop() {}

const _idle = _Kind(
  name: 'idle',
  gaze: AppHeroGaze.card,
  card: AppStatusCard(
    label: 'WILL IT WAKE ME',
    numeral: '7/7',
    pips: [
      AppPipTone.fine,
      AppPipTone.fine,
      AppPipTone.fine,
      AppPipTone.fine,
      AppPipTone.fine,
      AppPipTone.fine,
      AppPipTone.fine,
    ],
    foot: 'last alarm 00:46',
  ),
);

const _ringing = _Kind(
  name: 'ringing',
  severity: SeverityMode.crit,
  face: FaceState.alarmed,
  isLive: true,
  card: AppStatusCard(
    label: 'RINGING',
    numeral: '2:17',
    numeralTone: AppStatusTone.red,
    foot: 'prod-db',
    actionLabel: 'Open the alarm',
    onAction: _noop,
    popsOnChange: false,
  ),
);

const _issueLook = _Kind(
  name: 'issue, needs a look',
  face: FaceState.skeptical,
  tone: AppHeroTone.look,
  card: AppStatusCard(
    label: 'WILL IT WAKE ME',
    numeral: '6/7',
    numeralTone: AppStatusTone.orange,
    pips: [
      AppPipTone.fine,
      AppPipTone.fine,
      AppPipTone.fine,
      AppPipTone.fine,
      AppPipTone.fine,
      AppPipTone.fine,
      AppPipTone.look,
    ],
    foot: 'battery saver is on',
    footTone: AppStatusTone.orangeSoft,
    actionLabel: 'Fix this',
    onAction: _noop,
  ),
);

const _kinds = <_Kind>[
  _Kind(
    name: 'loading',
    card: AppStatusCard(
      label: 'WILL IT WAKE ME',
      numeral: '···',
      numeralTone: AppStatusTone.muted,
      foot: 'asking the server',
    ),
  ),
  _ringing,
  _Kind(
    name: 'acknowledged',
    severity: SeverityMode.ack,
    face: FaceState.acked,
    card: AppStatusCard(
      label: 'RINGS AGAIN IN',
      numeral: '9 min',
      foot: 'prod-db, unless closed',
      actionLabel: 'Open it',
      onAction: _noop,
    ),
  ),
  _Kind(
    name: 'handled',
    face: FaceState.happy,
    card: AppStatusCard(
      label: 'ANSWERED IN',
      numeral: '11 s',
      foot: 'prod-db, closed 06:14',
    ),
  ),
  _Kind(
    name: 'missed',
    face: FaceState.skeptical,
    tone: AppHeroTone.danger,
    card: AppStatusCard(
      label: 'MISSED',
      numeral: '1',
      numeralTone: AppStatusTone.red,
      foot: 'rang 10 min at 03:12',
      actionLabel: 'See why',
      onAction: _noop,
    ),
  ),
  _Kind(
    name: 'no server',
    face: FaceState.sad,
    tone: AppHeroTone.danger,
    card: AppStatusCard(
      numeral: 'No',
      numeralTone: AppStatusTone.red,
      foot: 'no server connected',
      footTone: AppStatusTone.red,
      actionLabel: 'Connect a server',
      onAction: _noop,
    ),
  ),
  _Kind(
    name: 'stale',
    face: FaceState.watching,
    tone: AppHeroTone.quiet,
    card: AppStatusCard(
      label: 'SERVER LAST SEEN',
      numeral: '23:10',
      numeralTone: AppStatusTone.muted,
      foot: 'not answering now',
      actionLabel: 'Try again',
      onAction: _noop,
    ),
  ),
  _Kind(
    name: 'load failed',
    face: FaceState.watching,
    tone: AppHeroTone.quiet,
    card: AppStatusCard(
      label: 'SERVER',
      numeral: '?',
      numeralTone: AppStatusTone.muted,
      foot: 'could not load the list',
      actionLabel: 'Try again',
      onAction: _noop,
    ),
  ),
  _Kind(
    name: 'no topics',
    face: FaceState.interested,
    card: AppStatusCard(
      label: 'TOPICS',
      numeral: '0',
      numeralTone: AppStatusTone.muted,
      foot: 'nothing can reach you yet',
    ),
  ),
  _Kind(
    name: 'issue, broken',
    face: FaceState.sad,
    tone: AppHeroTone.look,
    card: AppStatusCard(
      label: 'WILL IT WAKE ME',
      numeral: '6/7',
      numeralTone: AppStatusTone.red,
      pips: [
        AppPipTone.fine,
        AppPipTone.fine,
        AppPipTone.fine,
        AppPipTone.fine,
        AppPipTone.fine,
        AppPipTone.fine,
        AppPipTone.broken,
      ],
      foot: 'notifications are off',
      footTone: AppStatusTone.red,
      actionLabel: 'Fix this',
      onAction: _noop,
    ),
  ),
  _issueLook,
  _Kind(
    name: 'warning',
    severity: SeverityMode.high,
    face: FaceState.worried,
    card: AppStatusCard(
      label: 'NEEDS A LOOK',
      numeral: '2',
      numeralTone: AppStatusTone.orangeSoft,
      foot: 'topics sent a warning',
    ),
  ),
  _Kind(
    name: 'setup',
    card: AppStatusCard(
      label: 'SETUP',
      numeral: '1/3',
      pips: [AppPipTone.fine, AppPipTone.open, AppPipTone.open],
      foot: 'next: turn on Critical',
      actionLabel: 'Continue',
      onAction: _noop,
    ),
  ),
  _Kind(
    name: 'waiting',
    face: FaceState.watching,
    card: AppStatusCard(
      label: 'FIRST MESSAGE',
      numeral: 'Not yet',
      numeralTone: AppStatusTone.muted,
      foot: 'send the line below',
    ),
  ),
  _Kind(
    name: 'quiet',
    face: FaceState.dozing,
    tone: AppHeroTone.quiet,
    card: AppStatusCard(
      label: 'QUIET FOR',
      numeral: '23 d',
      foot: 'last alarm 16 Sep',
      actionLabel: 'Send a test',
      onAction: _noop,
    ),
  ),
  // The Topic screen: the Critical switch in the card's trailing slot, in the
  // panel variant. The off track is outlined so it shows on the dark card.
  _Kind(
    name: 'topic, critical on',
    gaze: AppHeroGaze.card,
    card: AppStatusCard(
      label: 'CRITICAL DELIVERY',
      numeral: 'On',
      foot: 'rings through silent',
      trailing: AppSwitch(value: true, variant: AppSwitchVariant.panel),
    ),
  ),
  _Kind(
    name: 'topic, critical off',
    gaze: AppHeroGaze.card,
    tone: AppHeroTone.quiet,
    card: AppStatusCard(
      label: 'CRITICAL DELIVERY',
      numeral: 'Off',
      numeralTone: AppStatusTone.muted,
      foot: 'arrives as a normal push',
      trailing: AppSwitch(value: false, variant: AppSwitchVariant.panel),
    ),
  ),
  _idle,
];

/// A tile with the canvas a card sits on, retinted for a severity canvas.
class _CanvasTile extends StatelessWidget {
  const _CanvasTile({
    required this.severity,
    required this.child,
  });

  final SeverityMode severity;
  final Widget child;

  @override
  Widget build(BuildContext context) => SeverityScope(
    severity: severity,
    child: Builder(
      builder: (context) => DecoratedBox(
        decoration: BoxDecoration(
          color: context.appColors.canvas,
          borderRadius: Radii.mdAll,
          border: Border.all(color: context.appColors.hairline),
        ),
        child: Padding(padding: const EdgeInsets.all(Spacing.s3), child: child),
      ),
    ),
  );
}

/// Every card and the three strips, each on its own canvas.
class StatusCardsGallery extends StatelessWidget {
  const StatusCardsGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading(
          'Status card',
          'The dark card that answers one question. In the dark theme it takes '
              'the elevated fill and a panel outline, because the panel itself '
              'is 1.06 to 1 against the canvas. Each card is drawn on the '
              'canvas it lives on.',
        ),
        Wrap(
          spacing: Spacing.s4,
          runSpacing: Spacing.s4,
          children: [
            for (final kind in _kinds)
              SizedBox(
                width: 226,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Caption(kind.name),
                    _CanvasTile(
                      severity: kind.severity,
                      child: kind.card,
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: Spacing.s5),
        const _Caption(
          'strip: fine, look, broken, and a long title that stacks the '
          'numeral under it',
        ),
        const Wrap(
          spacing: Spacing.s4,
          runSpacing: Spacing.s4,
          children: [
            _StripDemo(
              face: FaceState.happy,
              title: 'All checks pass',
              foot: 'An alarm should ring.',
              numeral: '7/7',
              numeralTone: AppStatusTone.yellow,
              tones: [
                AppPipTone.fine,
                AppPipTone.fine,
                AppPipTone.fine,
                AppPipTone.fine,
                AppPipTone.fine,
                AppPipTone.fine,
                AppPipTone.fine,
              ],
            ),
            _StripDemo(
              face: FaceState.skeptical,
              title: 'Battery saver is on',
              foot: 'It can stop an alarm.',
              numeral: '6/7',
              numeralTone: AppStatusTone.orange,
              action: 'Fix this',
              tones: [
                AppPipTone.fine,
                AppPipTone.fine,
                AppPipTone.fine,
                AppPipTone.fine,
                AppPipTone.fine,
                AppPipTone.fine,
                AppPipTone.look,
              ],
            ),
            _StripDemo(
              face: FaceState.sad,
              title: 'Notifications are off',
              foot: 'An alarm will not ring.',
              numeral: '6/7',
              numeralTone: AppStatusTone.red,
              action: 'Fix this',
              tones: [
                AppPipTone.fine,
                AppPipTone.fine,
                AppPipTone.fine,
                AppPipTone.fine,
                AppPipTone.fine,
                AppPipTone.fine,
                AppPipTone.broken,
              ],
            ),
            _StripDemo(
              face: FaceState.skeptical,
              title:
                  'Battery saver is on and the last push did not reach '
                  'this phone',
              foot: 'It can stop an alarm.',
              numeral: '5/7',
              numeralTone: AppStatusTone.orange,
              action: 'Fix this',
              tones: [
                AppPipTone.fine,
                AppPipTone.fine,
                AppPipTone.fine,
                AppPipTone.fine,
                AppPipTone.fine,
                AppPipTone.look,
                AppPipTone.look,
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _StripDemo extends StatelessWidget {
  const _StripDemo({
    required this.face,
    required this.title,
    required this.foot,
    required this.numeral,
    required this.numeralTone,
    required this.tones,
    this.action,
  });

  final FaceState face;
  final String title;
  final String foot;
  final String numeral;
  final AppStatusTone numeralTone;
  final List<AppPipTone> tones;
  final String? action;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 366,
    child: _CanvasTile(
      severity: SeverityMode.none,
      child: AppStatusCard.strip(
        face: face,
        label: 'WILL IT WAKE ME',
        title: title,
        foot: foot,
        numeral: numeral,
        numeralTone: numeralTone,
        pips: tones,
        actionLabel: action,
        onAction: action == null ? null : _noop,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Pips.
// ---------------------------------------------------------------------------

/// Pips for 6, 7, 8 and 9 checks, and setup 1 of 3.
class ReadinessPipsGallery extends StatelessWidget {
  const ReadinessPipsGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final panel = statusCardSurface(colors, Theme.of(context).brightness);

    Widget cell(String caption, List<AppPipTone> tones, double width) =>
        SizedBox(
          width: width + 36,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Caption(caption),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: panel.fill,
                  borderRadius: Radii.lgAll,
                  border: panel.line == null
                      ? null
                      : Border.all(color: panel.line!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: AppReadinessPips(tones: tones),
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading(
          'Readiness pips',
          'One pip per check, fine first. The numeral beside them carries the '
              'count, so colour is never the only signal. Nine pips stay 10 '
              'points wide on the narrowest card (140).',
        ),
        for (final count in [6, 7, 8, 9]) ...[
          Wrap(
            spacing: Spacing.s3,
            runSpacing: Spacing.s3,
            children: [
              cell('$count: all fine', pipTones(fine: count), 140),
              cell(
                '$count: one look',
                pipTones(fine: count - 1, look: 1),
                140,
              ),
              cell(
                '$count: one broken',
                pipTones(fine: count - 1, broken: 1),
                140,
              ),
            ],
          ),
          const SizedBox(height: Spacing.s3),
        ],
        Wrap(
          spacing: Spacing.s3,
          runSpacing: Spacing.s3,
          children: [
            cell('setup 1 of 3', pipTones(fine: 1, open: 2), 140),
            cell('9, on a wide card', pipTones(fine: 8, broken: 1), 260),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero scene.
// ---------------------------------------------------------------------------

/// Three kinds at 320, 390 and a 360 point pane, at text scale 1, 1.3, 2.
class HeroSceneGallery extends StatelessWidget {
  const HeroSceneGallery({
    this.widths = const [(320.0, false), (390.0, false), (360.0, true)],
    this.scales = const [1.0, 1.3, 2.0],
    super.key,
  });

  /// Each width, and whether that one is a pane.
  final List<(double, bool)> widths;

  /// The text scales.
  final List<double> scales;

  @override
  Widget build(BuildContext context) {
    const list = [_idle, _ringing, _issueLook];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading(
          'Hero scene',
          'The face, the card and a breathing disc. It stacks under 340 '
              'points, above text scale 1.3 and in a pane. Nothing plays when '
              'it first appears. Turn motion off above to see the resting '
              'frame.',
        ),
        for (final kind in list)
          for (final scale in scales) ...[
            _Caption('${kind.name} at text ${scale}x'),
            Wrap(
              spacing: Spacing.s4,
              runSpacing: Spacing.s4,
              children: [
                for (final (width, isPane) in widths)
                  SizedBox(
                    width: width,
                    child: _HeroDemo(
                      kind: kind,
                      scale: scale,
                      isPane: isPane,
                      caption: '${width.round()}${isPane ? ' pane' : ''}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.s5),
          ],
      ],
    );
  }
}

class _HeroDemo extends StatelessWidget {
  const _HeroDemo({
    required this.kind,
    required this.scale,
    required this.isPane,
    required this.caption,
  });

  final _Kind kind;
  final double scale;
  final bool isPane;
  final String caption;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: SeverityScope(
      severity: kind.severity,
      child: Builder(
        builder: (context) {
          final colors = context.appColors;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                caption,
                style: AppTypography.mono(colors.onCanvasMuted, fontSize: 10),
              ),
              ClipRRect(
                borderRadius: Radii.mdAll,
                child: ColoredBox(
                  color: colors.canvas,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: Spacing.s5),
                      // The tile has a canvas of its own, not the app's, so
                      // the scene draws its own disc and ring here.
                      AmbientScope(
                        isActive: false,
                        child: AppHeroScene(
                          face: kind.face,
                          tone: kind.tone,
                          gaze: kind.gaze,
                          isLive: kind.isLive,
                          isPane: isPane,
                          card: kind.card,
                        ),
                      ),
                      // The top of the white sheet, so the disc is seen going
                      // under it.
                      const SizedBox(height: Spacing.s4),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppInboxSheet.radius),
                          ),
                        ),
                        child: const SizedBox(height: 36),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Inbox rows.
// ---------------------------------------------------------------------------

/// Every row kind, a long name and a long message, on the white sheet.
class InboxRowsGallery extends StatelessWidget {
  const InboxRowsGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading(
          'Inbox rows',
          'One white sheet, a hairline between rows, no card per row. A face '
              'only for a topic that needs a look. At large text the time '
              'drops under the name.',
        ),
        const _Caption('normal, unread, pinned, quiet hours, muted'),
        _sheet(const [
          AppInboxRow(
            name: 'nas-backup',
            message:
                'Nightly backup finished, 412 GB in 38 min. Next run '
                'tomorrow 02:00.',
            time: '02:00',
          ),
          AppInboxRow(
            name: 'uptime-kuma',
            kind: AppInboxRowKind.unread,
            unreadCount: 2,
            hasCriticalDelivery: true,
            criticalLabel: 'Critical delivery is on',
            message:
                '[api.example.com] is back up after 4 min. Status 200, '
                '312 ms.',
            time: '00:46',
          ),
          AppInboxRow(
            name: 'prod-db',
            isPinned: true,
            hasCriticalDelivery: true,
            criticalLabel: 'Critical delivery is on',
            message: 'Disk 91% on /var, replica lag 40 s.',
            time: '06:12',
          ),
          AppInboxRow(
            name: 'github-ci',
            isQuietHours: true,
            quietLabel: 'Quiet hours are on',
            message: 'main: build 4812 passed in 6 min 20 s.',
            time: 'Yesterday',
          ),
          AppInboxRow(
            name: 'home-ha',
            kind: AppInboxRowKind.muted,
            message: 'Front door unlocked at 18:40 by keypad.',
            time: 'Muted',
          ),
        ]),
        const SizedBox(height: Spacing.s5),
        const _Caption('needs you: ringing, acknowledged, warning'),
        _sheet(const [
          AppInboxRow(
            name: 'prod-db',
            kind: AppInboxRowKind.ringing,
            hasCriticalDelivery: true,
            criticalLabel: 'Critical delivery is on',
            message:
                'Primary database down. Connection pool exhausted '
                '(500/500 connections in use).',
            time: 'Ringing',
          ),
          AppInboxRow(
            name: 'prod-db',
            kind: AppInboxRowKind.acknowledged,
            message:
                'Primary database down. Connection pool exhausted '
                '(500/500 connections in use).',
            time: 'Acknowledged',
          ),
          AppInboxRow(
            name: 'nas-backup',
            kind: AppInboxRowKind.warning,
            message: 'Backup failed: target volume is read-only.',
            time: '06:40',
          ),
          AppInboxRow(
            name: 'github-ci',
            kind: AppInboxRowKind.warning,
            unreadCount: 1,
            message: 'main: build 4813 failed in test (3 failures).',
            time: '06:31',
          ),
        ]),
        const SizedBox(height: Spacing.s5),
        const _Caption('missed, handled'),
        _sheet(const [
          AppInboxRow(
            name: 'prod-db',
            kind: AppInboxRowKind.missed,
            unreadCount: 1,
            hasCriticalDelivery: true,
            criticalLabel: 'Critical delivery is on',
            message:
                'Primary database down. Connection pool exhausted '
                '(500/500 connections in use).',
            time: 'Nobody answered',
          ),
          AppInboxRow(
            name: 'prod-db',
            kind: AppInboxRowKind.handled,
            message:
                'Primary database down. Connection pool exhausted '
                '(500/500 connections in use).',
            time: 'Handled 06:14',
          ),
        ]),
        const SizedBox(height: Spacing.s5),
        const _Caption('long name, long message, 120 unread'),
        _sheet(const [
          AppInboxRow(
            name: 'production-eu-west-1-primary-database-replica-lag-monitor',
            hasCriticalDelivery: true,
            criticalLabel: 'Critical delivery is on',
            isPinned: true,
            isQuietHours: true,
            quietLabel: 'Quiet hours are on',
            kind: AppInboxRowKind.unread,
            unreadCount: 120,
            message:
                'Replica lag has been above 40 seconds for 12 minutes on '
                'orders-replica-3. Autovacuum is still running on the orders '
                'table and the connection pool is close to its limit, so new '
                'writes may queue.',
            time: '06:12',
          ),
        ]),
      ],
    );
  }

  Widget _sheet(List<Widget> rows) => AppInboxSheet(children: rows);
}

// ---------------------------------------------------------------------------
// Cream cards.
// ---------------------------------------------------------------------------

/// Each use of the cream card, with and without the cross, on the yellow
/// canvas and on the white sheet.
class CreamCardGallery extends StatelessWidget {
  const CreamCardGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    Widget onSheet(Widget child) => DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppInboxSheet.radius),
      ),
      child: Padding(padding: const EdgeInsets.all(10), child: child),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading(
          'Cream card',
          'Back up, widgets, day 0, one topic so far, and the curl line. '
              'Cream on the yellow canvas has no stroke. Cream on the white '
              'sheet keeps the ink stroke.',
        ),
        const _Caption('on the canvas, with a cross'),
        const AppCreamCard(
          title: 'Back up your topics',
          body: 'Sign in so a new phone gets them back.',
          actionLabel: 'Sign in',
          onAction: _noop,
          onClose: _noop,
          closeLabel: 'Close',
        ),
        const SizedBox(height: Spacing.s3),
        const _Caption('on the canvas, no cross'),
        const AppCreamCard(
          title: 'Put Crit Alarm on your home screen',
          body: 'A widget shows the last message.',
          actionLabel: 'Show me',
          onAction: _noop,
        ),
        const SizedBox(height: Spacing.s3),
        const _Caption('on the sheet, with a cross'),
        onSheet(
          const AppCreamCard(
            title: 'One topic so far',
            body: 'Add one for each tool that should reach you.',
            actionLabel: 'New topic',
            onAction: _noop,
            isOnSheet: true,
            onClose: _noop,
            closeLabel: 'Close',
          ),
        ),
        const SizedBox(height: Spacing.s3),
        const _Caption('on the sheet, curl line'),
        onSheet(
          const AppCreamCard(
            title: 'curl -d "hello" .../uptime-kuma',
            isMonoTitle: true,
            body: 'Sends one message to this topic.',
            actionLabel: 'Open it',
            onAction: _noop,
            isOnSheet: true,
          ),
        ),
        const SizedBox(height: Spacing.s3),
        const _Caption('narrow column (260)'),
        const SizedBox(
          width: 260,
          child: AppCreamCard(
            title: 'Back up your topics',
            body: 'Sign in so a new phone gets them back.',
            actionLabel: 'Sign in',
            onAction: _noop,
            onClose: _noop,
            closeLabel: 'Close',
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stat card.
// ---------------------------------------------------------------------------

/// A full week, an empty week, one alarm, and a plan that keeps three days.
class StatCardGallery extends StatelessWidget {
  const StatCardGallery({super.key});

  static AppStatDay _d(
    String letter,
    String name, {
    int alarms = 0,
    bool today = false,
    bool unanswered = false,
    bool hidden = false,
  }) => AppStatDay(
    letter: letter,
    alarms: alarms,
    isToday: today,
    hasUnanswered: unanswered,
    isHidden: hidden,
    semanticsLabel: hidden
        ? "$name: outside your plan's history"
        : alarms == 0
        ? '$name: no alarms'
        : '$name: $alarms ${alarms == 1 ? 'alarm' : 'alarms'}'
              '${unanswered ? ', not answered' : ''}',
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading(
          'Stat card',
          'A week of seven bars and two numbers. Today is yellow, a day with '
              'an unanswered alarm is red, a quiet day is a short stub and a '
              'day the plan does not reach has no bar. The numbers sit left '
              'and the bars right; on a narrow card or at a large text size '
              'the bars go on top.',
        ),
        const _Caption('a full week'),
        AppStatCard(
          days: [
            _d('F', 'Friday'),
            _d('S', 'Saturday', alarms: 1),
            _d('S', 'Sunday'),
            _d('M', 'Monday', alarms: 1, unanswered: true),
            _d('T', 'Tuesday', alarms: 2),
            _d('W', 'Wednesday'),
            _d('T', 'Thursday', alarms: 3, today: true),
          ],
          firstValue: '7',
          firstCaption: 'alarms, 7 days',
          secondValue: '11 s',
          secondCaption: 'longest answered',
          semanticsLabel: 'Alarms per day, last 7 days',
        ),
        const SizedBox(height: Spacing.s4),
        const _Caption('an empty week'),
        AppStatCard(
          days: [
            _d('F', 'Friday'),
            _d('S', 'Saturday'),
            _d('S', 'Sunday'),
            _d('M', 'Monday'),
            _d('T', 'Tuesday'),
            _d('W', 'Wednesday'),
            _d('T', 'Thursday', today: true),
          ],
          firstValue: '0',
          firstCaption: 'alarms, 7 days',
          secondValue: 'None',
          secondCaption: 'longest answered',
          semanticsLabel: 'Alarms per day, last 7 days',
        ),
        const SizedBox(height: Spacing.s4),
        const _Caption('one alarm'),
        AppStatCard(
          days: [
            _d('F', 'Friday'),
            _d('S', 'Saturday'),
            _d('S', 'Sunday'),
            _d('M', 'Monday'),
            _d('T', 'Tuesday'),
            _d('W', 'Wednesday', alarms: 1),
            _d('T', 'Thursday', today: true),
          ],
          firstValue: '1',
          firstCaption: 'alarm, 7 days',
          secondValue: '7 s',
          secondCaption: 'longest answered',
          semanticsLabel: 'Alarms per day, last 7 days',
        ),
        const SizedBox(height: Spacing.s4),
        const _Caption('a plan that keeps three days, with a missed alarm'),
        AppStatCard(
          days: [
            _d('F', 'Friday', hidden: true),
            _d('S', 'Saturday', hidden: true),
            _d('S', 'Sunday', hidden: true),
            _d('M', 'Monday', hidden: true),
            _d('T', 'Tuesday', alarms: 1, unanswered: true),
            _d('W', 'Wednesday'),
            _d('T', 'Thursday', alarms: 2, today: true),
          ],
          firstValue: '3',
          firstCaption: 'alarms, 3 days',
          secondValue: '6 min',
          secondCaption: 'longest answered',
          semanticsLabel: 'Alarms per day, last 3 days',
        ),
      ],
    );
  }
}
