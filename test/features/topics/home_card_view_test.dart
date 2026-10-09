import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/design/ambient/ambient.dart';
import 'package:critalarm/design/components/inbox_row.dart';
import 'package:critalarm/design/components/readiness_pips.dart';
import 'package:critalarm/design/components/status_card.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_input.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_kind.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_model.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_rule.dart';
import 'package:critalarm/features/topics/domain/home_card/inbox_order.dart';
import 'package:critalarm/features/topics/domain/home_card/setup_finish_card.dart';
import 'package:critalarm/features/topics/presentation/home_card_view.dart';
import 'package:critalarm/features/topics/presentation/home_inbox_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'domain/home_card/home_card_fixtures.dart' as fx;

void main() {
  final now = fx.now;

  group('homeCardNumeralText', () {
    String text(HomeCardNumeral n) => homeCardNumeralText(n, now: now);

    test('plain values', () {
      expect(text(const Dots()), '···');
      expect(text(const No()), 'No');
      expect(text(const Unknown()), '?');
      expect(text(const NotYet()), 'Not yet');
      expect(text(const Count(6, 7)), '6/7');
      expect(text(const Number(2)), '2');
      expect(text(const Seconds(11)), '11 s');
      expect(text(const Days(23)), '23 d');
    });

    test('a ringing clock reads minutes and seconds', () {
      final since = now.subtract(const Duration(minutes: 2, seconds: 17));
      expect(text(Elapsed(since)), '2:17');
      expect(text(Elapsed(now.add(const Duration(seconds: 4)))), '0:00');
    });

    test('a desk timer reads whole minutes, then seconds', () {
      expect(
        text(Remaining(now.add(const Duration(minutes: 8, seconds: 20)))),
        '9 min',
      );
      expect(text(Remaining(now.add(const Duration(seconds: 42)))), '0:42');
      expect(
        text(Remaining(now.subtract(const Duration(seconds: 1)))),
        '0:00',
      );
    });
  });

  group('homeCardViewFor', () {
    test('a ringing alarm: red clock, shaking face, open the alarm', () {
      final model = resolveHomeCard(
        HomeCardInput(
          now: now,
          topicCount: 1,
          ringing: RingingFact(
            incidentId: 'inc-1',
            topic: 'prod-db',
            openedAt: now.subtract(const Duration(minutes: 2, seconds: 17)),
          ),
        ),
      );
      final view = homeCardViewFor(model, now: now);
      expect(view.label, 'RINGING');
      expect(view.numeral, '2:17');
      expect(view.numeralTone, AppStatusTone.red);
      expect(view.foot, 'prod-db');
      expect(view.actionLabel, 'Open the alarm');
      expect(view.isLive, isTrue);
      expect(view.ticks, isTrue);
    });

    test('no server: the word No, red, and a way to connect', () {
      final model = resolveHomeCard(
        HomeCardInput(now: now, hasServer: false),
      );
      final view = homeCardViewFor(model, now: now);
      expect(view.numeral, 'No');
      expect(view.foot, 'no server connected');
      expect(view.footTone, AppStatusTone.red);
      expect(view.actionLabel, 'Connect a server');
      expect(view.heroTone, AppHeroTone.danger);
    });

    test('loading draws dots, never a count', () {
      final model = resolveHomeCard(HomeCardInput(now: now, isLoading: true));
      final view = homeCardViewFor(model, now: now);
      expect(view.numeral, '···');
      expect(view.pips, isNull);
      expect(view.ticks, isFalse);
    });

    test('a failing check names itself and offers its fix', () {
      final checks = fx.withCheckAt(
        fx.androidChecks(7),
        2,
        ReliabilityState.broken,
      );
      final model = resolveHomeCard(
        HomeCardInput(
          now: now,
          topicCount: 1,
          readiness: ReadinessInput(loaded: true, checks: checks),
        ),
      );
      final view = homeCardViewFor(model, now: now);
      expect(view.numeral, '6/7');
      expect(view.foot, 'battery saver is on');
      expect(view.pips, hasLength(7));
      expect(view.pips![2], AppPipTone.broken);
    });

    test('an unknown check gets the general line', () {
      expect(
        homeCardCheckFoot(const ReliabilityCheckId('something_new')),
        'a check needs a look',
      );
      expect(homeCardCheckFoot(null), 'a check needs a look');
    });

    test('the finish card fills every pip and reads 3/3', () {
      final view = homeCardViewFor(setupFinishCard(), now: now);
      expect(view.numeral, '3/3');
      expect(view.pips, hasLength(3));
      expect(view.pips, everyElement(AppPipTone.fine));
      expect(view.actionLabel, isNull);
      expect(view.foot, 'all set');
    });

    test('idle with no Critical topic says so', () {
      final model = resolveHomeCard(
        HomeCardInput(
          now: now,
          topicCount: 1,
          readiness: ReadinessInput(loaded: true, checks: fx.androidChecks(7)),
        ),
      );
      expect(model.kind, HomeCardKind.idle);
      expect(homeCardViewFor(model, now: now).foot, 'no Critical topic yet');
    });
  });

  group('homeAmbientProfile', () {
    const colors = AppColors.light;

    AmbientProfile profileOf(HomeCardInput input) =>
        homeAmbientProfile(resolveHomeCard(input), colors);

    test('a ringing alarm is on the red canvas', () {
      final profile = profileOf(
        HomeCardInput(
          now: now,
          topicCount: 1,
          ringing: RingingFact(
            incidentId: 'inc-1',
            topic: 'prod-db',
            openedAt: now.subtract(const Duration(minutes: 2)),
          ),
        ),
      );
      expect(profile.canvas, colors.critCanvas);
      expect(profile.shapes.first.color, colors.critCanvasAlt);
    });

    test('a calm card is on the yellow ground with the pale disc', () {
      final profile = profileOf(
        HomeCardInput(
          now: now,
          topicCount: 1,
          readiness: ReadinessInput(loaded: true, checks: fx.androidChecks(7)),
        ),
      );
      expect(profile.canvas, colors.canvas);
      expect(profile, AmbientAppProfiles.topicsHero(colors));
    });

    test('no server tints the disc red on the yellow ground', () {
      final profile = profileOf(HomeCardInput(now: now, hasServer: false));
      expect(profile.canvas, colors.canvas);
      expect(profile.shapes.first.color, colors.crit);
      expect(profile.shapes.first.opacity, 0.3);
    });

    test('each card kind keeps the profile apart from its neighbour', () {
      final idle = profileOf(
        HomeCardInput(
          now: now,
          topicCount: 1,
          readiness: ReadinessInput(loaded: true, checks: fx.androidChecks(7)),
        ),
      );
      final noServer = profileOf(HomeCardInput(now: now, hasServer: false));
      final loading = profileOf(HomeCardInput(now: now, isLoading: true));
      expect(idle, isNot(noServer));
      expect(loading, idle, reason: 'loading is a calm card');
    });

    test('the finish card is calm, so the canvas does not change', () {
      expect(
        homeAmbientProfile(setupFinishCard(), colors),
        AmbientAppProfiles.topicsHero(colors),
      );
    });

    test('the spot is passed on to the disc', () {
      const spot = HeroDiscSpot(
        anchor: Alignment(0.3, 0.2),
        discScale: 1.1,
        ringScale: 1.4,
      );
      final profile = homeAmbientProfile(
        setupFinishCard(),
        colors,
        spot: spot,
      );
      expect(profile.shapes.first.anchor, spot.anchor);
      expect(profile.shapes.last.scale, spot.ringScale);
    });
  });

  group('inbox rows', () {
    test('the kind follows the state, then muted, then unread', () {
      AppInboxRowKind kind(InboxRowKind s, {bool muted = false, int n = 0}) =>
          inboxRowKindFor(state: s, isMuted: muted, unreadCount: n);
      expect(kind(InboxRowKind.ringing, muted: true), AppInboxRowKind.ringing);
      expect(kind(InboxRowKind.normal, muted: true), AppInboxRowKind.muted);
      expect(kind(InboxRowKind.normal, n: 2), AppInboxRowKind.unread);
      expect(kind(InboxRowKind.normal), AppInboxRowKind.normal);
    });

    test('a row that needs you names its state in the time cell', () {
      String time(InboxRowKind s) =>
          inboxTimeText(state: s, lastMessageAt: now, now: now);
      expect(time(InboxRowKind.ringing), 'Ringing');
      expect(time(InboxRowKind.missed), 'Nobody answered');
      expect(time(InboxRowKind.handled), 'Handled');
    });

    test('a quiet row shows the hour, Yesterday, then a date', () {
      String time(Duration ago) => inboxTimeText(
        state: InboxRowKind.normal,
        lastMessageAt: now.subtract(ago),
        now: now,
      );
      expect(time(const Duration(hours: 3)), '09:00');
      expect(time(const Duration(days: 1)), 'Yesterday');
      expect(time(const Duration(days: 3)), '6 Oct');
      expect(time(const Duration(days: 30)), '9 Sep');
      expect(
        inboxTimeText(
          state: InboxRowKind.normal,
          lastMessageAt: null,
          now: now,
        ),
        '',
      );
    });

    test('the bell words follow the ring claim', () {
      expect(inboxBellLabel(RingClaim.alarm), 'Rings through silent mode');
      expect(
        inboxBellLabel(RingClaim.timeSensitive),
        'Loud alert, silent mode mutes it',
      );
    });
  });
}
