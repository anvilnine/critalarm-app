import 'dart:math' as math;

import 'package:critalarm/design/components/badges.dart';
import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/components/chips.dart';
import 'package:critalarm/design/components/code_block.dart';
import 'package:critalarm/design/components/empty_state.dart';
import 'package:critalarm/design/components/inputs.dart';
import 'package:critalarm/design/components/key_value_rows.dart';
import 'package:critalarm/design/components/ladder_rows.dart';
import 'package:critalarm/design/components/list_rows.dart';
import 'package:critalarm/design/components/message_cards.dart';
import 'package:critalarm/design/components/notification_cards.dart';
import 'package:critalarm/design/components/preview_button.dart';
import 'package:critalarm/design/components/radios.dart';
import 'package:critalarm/design/components/sheets.dart';
import 'package:critalarm/design/components/switches.dart';
import 'package:critalarm/design/components/toasts.dart';
import 'package:critalarm/design/components/waveform_bars.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/faces/pulse_ring_widget.dart';
import 'package:critalarm/design/theme/severity.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// Full interactive GalleryScreen showcasing every token, face, and component
/// in the Crit Alarm Design System.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  SeverityMode _severity = SeverityMode.none;
  bool _isDark = false;

  bool _liveCalm = false;
  bool _liveWatching = true;
  bool _liveWorried = false;
  bool _liveAlarmed = true;
  bool _liveAcked = false;

  bool _toggleVal1 = true;
  bool _toggleVal2 = false;

  @override
  Widget build(BuildContext context) {
    final themeData = _isDark
        ? buildDarkTheme(severity: _severity)
        : buildLightTheme(severity: _severity);

    return Theme(
      data: themeData,
      child: SeverityScope(
        severity: _severity,
        child: Builder(
          builder: (context) {
            final colors = context.appColors;

            return Scaffold(
              backgroundColor: colors.canvas,
              body: SafeArea(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    24,
                    20,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopBar(context, colors),
                          const SizedBox(height: 32),
                          _buildIntroduction(colors),
                          const SizedBox(height: 48),
                          _buildFiveFacesSection(colors),
                          const SizedBox(height: 48),
                          _buildSwatchesSection(colors),
                          const SizedBox(height: 48),
                          _buildTypographySection(colors),
                          const SizedBox(height: 48),
                          _buildScalesSection(colors),
                          const SizedBox(height: 48),
                          _buildButtonsSection(colors),
                          const SizedBox(height: 48),
                          _buildInputsSection(colors),
                          const SizedBox(height: 48),
                          _buildChipsAndBadgesSection(colors),
                          const SizedBox(height: 48),
                          _buildToastsSection(colors),
                          const SizedBox(height: 48),
                          _buildListRowsSection(colors),
                          const SizedBox(height: 48),
                          _buildSoundRowsSection(colors),
                          const SizedBox(height: 48),
                          _buildCodeBlockSection(colors),
                          const SizedBox(height: 48),
                          _buildEmptyStateSection(colors),
                          const SizedBox(height: 48),
                          _buildControlsAndCardsSection(colors),
                          const SizedBox(height: 48),
                          _buildPriorityLadderSection(colors),
                          const SizedBox(height: 48),
                          _buildAlarmPreviewSection(colors),
                          const SizedBox(height: 64),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FaceWidget(state: FaceState.calm, size: 34),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Crit Alarm Design System',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.fontDisplay,
                    fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.03 * 22,
                    color: colors.onCanvas,
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: Radii.fullAll,
                  border: Border.all(color: colors.hairline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Severity: ',
                      style: TextStyle(
                        fontFamily: AppTypography.fontBody,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.ink3,
                      ),
                    ),
                    DropdownButton<SeverityMode>(
                      value: _severity,
                      isDense: true,
                      underline: const SizedBox(),
                      style: TextStyle(
                        fontFamily: AppTypography.fontMono,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: colors.ink,
                      ),
                      dropdownColor: colors.surface,
                      items: SeverityMode.values.map((mode) {
                        return DropdownMenuItem(
                          value: mode,
                          child: Text(mode.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (newMode) {
                        if (newMode != null) {
                          setState(() => _severity = newMode);
                        }
                      },
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => setState(() => _isDark = !_isDark),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: Radii.fullAll,
                    border: Border.all(color: colors.hairline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isDark ? 'Dark' : 'Light',
                        style: TextStyle(
                          fontFamily: AppTypography.fontBody,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.ink,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          _isDark
                              ? Icons.nightlight_round
                              : Icons.wb_sunny_rounded,
                          size: 14,
                          color: colors.surface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntroduction(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'One state that matters. The app shows it as a face.',
          style: AppTypography.display(colors.onCanvas, fontSize: 44),
        ),
        const SizedBox(height: 14),
        Text(
          'Round two, direction "the face". Saturated yellow with black '
          'type, drawn character in the middle, and one card with detail.',
          style: AppTypography.lead(colors.onCanvasMuted),
        ),
      ],
    );
  }

  Widget _buildFiveFacesSection(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Five states, one construction',
          style: AppTypography.headline(colors.onCanvas),
        ),
        const SizedBox(height: 6),
        Text(
          'Same head, same 10 unit stroke, same eye positions. '
          'Click a face to toggle live animation.',
          style: AppTypography.body(colors.onCanvasMuted),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;

            if (isNarrow) {
              return Column(
                children: [
                  _faceCard(
                    FaceState.calm,
                    'Calm',
                    'Nothing open. Round eyes, easy mouth.',
                    _liveCalm,
                    () => setState(() => _liveCalm = !_liveCalm),
                    colors,
                  ),
                  const SizedBox(height: 12),
                  _faceCard(
                    FaceState.watching,
                    'Watching',
                    'Waiting on input. Eyes drift, one brow up.',
                    _liveWatching,
                    () => setState(() => _liveWatching = !_liveWatching),
                    colors,
                  ),
                  const SizedBox(height: 12),
                  _faceCard(
                    FaceState.worried,
                    'Worried',
                    'High priority open. Pinching brows.',
                    _liveWorried,
                    () => setState(() => _liveWorried = !_liveWorried),
                    colors,
                    strokeColor: colors.high,
                  ),
                  const SizedBox(height: 12),
                  _faceCard(
                    FaceState.alarmed,
                    'Alarmed',
                    'Critical, ringing. Heavier stroke, shakes.',
                    _liveAlarmed,
                    () => setState(() => _liveAlarmed = !_liveAlarmed),
                    colors,
                    strokeColor: colors.crit,
                  ),
                  const SizedBox(height: 12),
                  _faceCard(
                    FaceState.acked,
                    'Acknowledged',
                    'You tapped. Eyes close, screen flips cobalt.',
                    _liveAcked,
                    () => setState(() => _liveAcked = !_liveAcked),
                    colors,
                    strokeColor: colors.cobalt,
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: _faceCard(
                    FaceState.calm,
                    'Calm',
                    'Nothing open. Round eyes, easy mouth.',
                    _liveCalm,
                    () => setState(() => _liveCalm = !_liveCalm),
                    colors,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _faceCard(
                    FaceState.watching,
                    'Watching',
                    'Waiting on input. Eyes drift, one brow up.',
                    _liveWatching,
                    () => setState(() => _liveWatching = !_liveWatching),
                    colors,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _faceCard(
                    FaceState.worried,
                    'Worried',
                    'High priority open. Pinching brows.',
                    _liveWorried,
                    () => setState(() => _liveWorried = !_liveWorried),
                    colors,
                    strokeColor: colors.high,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _faceCard(
                    FaceState.alarmed,
                    'Alarmed',
                    'Critical, ringing. Heavier stroke, shakes.',
                    _liveAlarmed,
                    () => setState(() => _liveAlarmed = !_liveAlarmed),
                    colors,
                    strokeColor: colors.crit,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _faceCard(
                    FaceState.acked,
                    'Acknowledged',
                    'You tapped. Eyes close, flips cobalt.',
                    _liveAcked,
                    () => setState(() => _liveAcked = !_liveAcked),
                    colors,
                    strokeColor: colors.cobalt,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Radii.mdAll,
            boxShadow: AppShadows.lightSm,
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '40px list row size: ',
                style: AppTypography.mono(colors.ink3, fontSize: 13),
              ),
              const FaceWidget(state: FaceState.calm, size: 40),
              const FaceWidget(state: FaceState.watching, size: 40),
              FaceWidget(
                state: FaceState.worried,
                size: 40,
                overrideStrokeColor: colors.high,
              ),
              FaceWidget(
                state: FaceState.alarmed,
                size: 40,
                overrideStrokeColor: colors.crit,
              ),
              FaceWidget(
                state: FaceState.acked,
                size: 40,
                overrideStrokeColor: colors.cobalt,
              ),
              Text(
                'stroke 10 / 200 viewBox',
                style: AppTypography.mono(colors.ink3, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _faceCard(
    FaceState state,
    String name,
    String caption,
    bool isLive,
    VoidCallback onTap,
    AppColors colors, {
    Color? strokeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: Radii.xlAll,
          boxShadow: AppShadows.lightSm,
        ),
        child: Column(
          children: [
            FaceWidget(
              state: state,
              size: 100,
              isLive: isLive,
              overrideStrokeColor: strokeColor,
            ),
            const SizedBox(height: 14),
            Text(
              name,
              style: TextStyle(
                fontFamily: AppTypography.fontDisplay,
                fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.fontBody,
                fontFamilyFallback: AppTypography.fontBodyFallbacks,
                fontSize: 12,
                color: colors.ink3,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isLive ? 'LIVE (tap to stop)' : 'PAUSED (tap to animate)',
              style: TextStyle(
                fontFamily: AppTypography.fontMono,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isLive ? colors.highlight : colors.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwatchesSection(AppColors colors) {
    final swatches = [
      (
        name: 'Canvas',
        hex: '#FFC93C',
        color: const Color(0xFFFFC93C),
        fg: const Color(0xFF1A140F),
        role: '--canvas. Full bleed, both apps.',
      ),
      (
        name: 'Canvas alt',
        hex: '#FFD866',
        color: const Color(0xFFFFD866),
        fg: const Color(0xFF1A140F),
        role: '--canvas-alt. Banded sections.',
      ),
      (
        name: 'Ink',
        hex: '#1A140F',
        color: const Color(0xFF1A140F),
        fg: const Color(0xFFFFC93C),
        role: '--ink, --on-canvas. Type, panels.',
      ),
      (
        name: 'Ink muted',
        hex: '#3A2A12',
        color: const Color(0xFF3A2A12),
        fg: const Color(0xFFFFC93C),
        role: '--on-canvas-muted. Second line.',
      ),
      (
        name: 'Cobalt',
        hex: '#2A3BD8',
        color: const Color(0xFF2A3BD8),
        fg: const Color(0xFFFFFFFF),
        role: '--cobalt. Primary action, hero box.',
      ),
      (
        name: 'Cobalt on canvas',
        hex: '#FFC93C',
        color: const Color(0xFFFFC93C),
        fg: const Color(0xFF2A3BD8),
        role: 'Links and focus ring on yellow.',
      ),
      (
        name: 'High',
        hex: '#FF8A1F',
        color: const Color(0xFFFF8A1F),
        fg: const Color(0xFF1A140F),
        role: '--high. Chip and canvas for high.',
      ),
      (
        name: 'Critical',
        hex: '#F5473A',
        color: const Color(0xFFF5473A),
        fg: const Color(0xFF1A140F),
        role: '--crit. Chip and canvas while ringing.',
      ),
      (
        name: 'Paper',
        hex: '#FFFFFF',
        color: const Color(0xFFFFFFFF),
        fg: const Color(0xFF1A140F),
        role: '--surface. Card on phone screen.',
      ),
      (
        name: 'Cream',
        hex: '#F7F2E9',
        color: const Color(0xFFF7F2E9),
        fg: const Color(0xFF1A140F),
        role: '--cream. Site cards at 32px radius.',
      ),
      (
        name: 'Ink 2 on paper',
        hex: '#FFFFFF',
        color: const Color(0xFFFFFFFF),
        fg: const Color(0xFF3E2C21),
        role: '--ink-2. Body inside a card.',
      ),
      (
        name: 'Ink 3 on paper',
        hex: '#FFFFFF',
        color: const Color(0xFFFFFFFF),
        fg: const Color(0xFF6E543F),
        role: '--ink-3. Meta inside a card.',
      ),
      (
        name: 'Dark canvas',
        hex: '#171310',
        color: const Color(0xFF171310),
        fg: const Color(0xFFF7F1EA),
        role: '--canvas (dark). Accent yellow.',
      ),
      (
        name: 'Dark cobalt text',
        hex: '#171310',
        color: const Color(0xFF171310),
        fg: const Color(0xFF7C8AFF),
        role: '--cobalt (dark). Buttons keep #2A3BD8.',
      ),
      (
        name: 'Dark critical canvas',
        hex: '#3A100D',
        color: const Color(0xFF3A100D),
        fg: const Color(0xFFF7F1EA),
        role: 'Alarm screen at 3am. Red outline face.',
      ),
      (
        name: 'Dark high canvas',
        hex: '#3A2208',
        color: const Color(0xFF3A2208),
        fg: const Color(0xFFF7F1EA),
        role: 'Topic detail with high message, dark.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Color', style: AppTypography.headline(colors.onCanvas)),
        const SizedBox(height: 6),
        Text(
          'Yellow is the canvas. Cobalt fights yellow on purpose. '
          'Orange and red are reserved for the priority ladder.',
          style: AppTypography.body(colors.onCanvasMuted),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: swatches.map((s) {
            final ratio = ColorContrast.contrastRatio(s.color, s.fg);
            final grade = ColorContrast.wcagGrade(ratio);

            return Container(
              width: 240,
              constraints: const BoxConstraints(minHeight: 150),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: s.color,
                borderRadius: Radii.mdAll,
                border: Border.all(color: colors.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: TextStyle(
                          fontFamily: AppTypography.fontDisplay,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: s.fg,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.role,
                        style: TextStyle(
                          fontFamily: AppTypography.fontBody,
                          fontSize: 11,
                          color: s.fg.withValues(alpha: 0.85),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          s.hex,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTypography.fontMono,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: s.fg,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${ratio.toStringAsFixed(2)}:1 $grade',
                        style: TextStyle(
                          fontFamily: AppTypography.fontMono,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: s.fg,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTypographySection(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Type Scale', style: AppTypography.headline(colors.onCanvas)),
        const SizedBox(height: 6),
        Text(
          'Bricolage Grotesque 800 display, Instrument Sans body, '
          'JetBrains Mono machine strings.',
          style: AppTypography.body(colors.onCanvasMuted),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Radii.xlAll,
            boxShadow: AppShadows.lightSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _typeRow(
                'display 800 / clamp(48,7vw,96)',
                Text(
                  'Wake up.',
                  style: AppTypography.display(colors.ink, fontSize: 52),
                ),
                colors,
              ),
              _typeRow(
                'headline 800 / clamp(30,3.6vw,46)',
                Text(
                  'Primary database down',
                  style: AppTypography.headline(colors.ink),
                ),
                colors,
              ),
              _typeRow(
                'title 700 / 20 / -.02em',
                Text('Quiet hours', style: AppTypography.title(colors.ink)),
                colors,
              ),
              _typeRow(
                'lead 500 / 18 / 1.5',
                Text(
                  'Point systems at one endpoint and get woken when they '
                  'break.',
                  style: AppTypography.lead(colors.ink),
                ),
                colors,
              ),
              _typeRow(
                'body 400 / 16 / 1.6',
                Text(
                  'Every topic gets a URL and a bearer token.',
                  style: AppTypography.body(colors.ink),
                ),
                colors,
              ),
              _typeRow(
                'small 500 / 14 / 1.4',
                Text(
                  'Lowercase, digits, hyphens. This becomes the URL.',
                  style: AppTypography.small(colors.ink),
                ),
                colors,
              ),
              _typeRow(
                'label 700 caps / 11 / 1px',
                Text(
                  'RINGING THROUGH SILENT MODE',
                  style: AppTypography.label(colors.ink),
                ),
                colors,
              ),
              _typeRow(
                'mono 500 / 14 / -.01em',
                Text(
                  'POST /t/prod-db  Priority: critical',
                  style: AppTypography.mono(colors.ink),
                ),
                colors,
              ),
              _typeRow(
                'mono 700 / 14 / -.01em',
                Text(
                  'ca_live_7Hq2mN9xPz4wKd8',
                  style: AppTypography.monoBold(colors.ink),
                ),
                colors,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _typeRow(String spec, Widget widget, AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 500) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec,
                  style: TextStyle(
                    fontFamily: AppTypography.fontMono,
                    fontSize: 12,
                    color: colors.ink3,
                  ),
                ),
                const SizedBox(height: 6),
                widget,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(
                width: 200,
                child: Text(
                  spec,
                  style: TextStyle(
                    fontFamily: AppTypography.fontMono,
                    fontSize: 12,
                    color: colors.ink3,
                  ),
                ),
              ),
              Expanded(child: widget),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScalesSection(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Spacing, Radii & Elevation',
          style: AppTypography.headline(colors.onCanvas),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            Container(
              width: 320,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: Radii.xlAll,
                boxShadow: AppShadows.lightSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spacing (9 steps)',
                    style: AppTypography.title(colors.ink),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      _spacingSquare(Spacing.s1, colors),
                      _spacingSquare(Spacing.s2, colors),
                      _spacingSquare(Spacing.s3, colors),
                      _spacingSquare(Spacing.s4, colors),
                      _spacingSquare(Spacing.s5, colors),
                      _spacingSquare(Spacing.s6, colors),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '4, 8, 12, 16, 24, 32, 48, 64, 96',
                    style: AppTypography.mono(colors.ink3, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              width: 320,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: Radii.xlAll,
                boxShadow: AppShadows.lightSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Radius (5 tiers)',
                    style: AppTypography.title(colors.ink),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _radiusBox(Radii.sm, 'sm', colors),
                      _radiusBox(Radii.md, 'md', colors),
                      _radiusBox(Radii.lg, 'lg', colors),
                      _radiusBox(Radii.xl, 'xl', colors),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 320,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.cream,
                borderRadius: Radii.xlAll,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Elevation',
                    style: AppTypography.title(colors.ink),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _elevationBox('sm', AppShadows.lightSm, colors),
                      _elevationBox('md', AppShadows.lightMd, colors),
                      _elevationBox('lg', AppShadows.lightLg, colors),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _spacingSquare(double size, AppColors colors) {
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          color: colors.ink,
        ),
        const SizedBox(height: 4),
        Text(
          size.toInt().toString(),
          style: TextStyle(
            fontFamily: AppTypography.fontMono,
            fontSize: 10,
            color: colors.ink3,
          ),
        ),
      ],
    );
  }

  Widget _radiusBox(double r, String label, AppColors colors) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: colors.cobaltTint,
        border: Border.all(color: colors.cobalt, width: 2),
        borderRadius: BorderRadius.circular(r),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTypography.fontMono,
          fontSize: 11,
          color: colors.ink,
        ),
      ),
    );
  }

  Widget _elevationBox(
    String label,
    List<BoxShadow> shadows,
    AppColors colors,
  ) {
    return Container(
      width: 70,
      height: 50,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.mdAll,
        boxShadow: shadows,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTypography.fontMono,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: colors.ink,
        ),
      ),
    );
  }

  Widget _buildButtonsSection(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Buttons', style: AppTypography.headline(colors.onCanvas)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Radii.xlAll,
            boxShadow: AppShadows.lightSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Variants & States', style: AppTypography.title(colors.ink)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  AppButton(
                    label: 'Primary',
                    onPressed: () {},
                  ),
                  AppButton(
                    label: 'Primary Focus',
                    isFocused: true,
                    onPressed: () {},
                  ),
                  AppButton(
                    label: 'Primary Loading',
                    isLoading: true,
                    onPressed: () {},
                  ),
                  const AppButton(
                    label: 'Primary Disabled',
                  ),
                  AppButton(
                    label: 'Ink Button',
                    variant: AppButtonVariant.ink,
                    onPressed: () {},
                  ),
                  AppButton(
                    label: 'Ghost Button',
                    variant: AppButtonVariant.ghost,
                    onPressed: () {},
                  ),
                  AppButton(
                    label: 'Paper Button',
                    variant: AppButtonVariant.paper,
                    onPressed: () {},
                  ),
                  AppButton(
                    label: 'Crit Button',
                    variant: AppButtonVariant.crit,
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Sizes', style: AppTypography.title(colors.ink)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppButton(
                    label: 'Small (36px)',
                    size: AppButtonSize.sm,
                    onPressed: () {},
                  ),
                  AppButton(
                    label: 'Medium (48px)',
                    onPressed: () {},
                  ),
                  AppButton(
                    label: 'Large (60px)',
                    size: AppButtonSize.lg,
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputsSection(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Inputs', style: AppTypography.headline(colors.onCanvas)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Radii.xlAll,
            boxShadow: AppShadows.lightSm,
          ),
          child: const Column(
            children: [
              AppTextField(
                label: 'Topic name (Rest)',
                placeholder: 'prod-db',
                helperText: 'Lowercase, digits, hyphens. This becomes the URL.',
              ),
              SizedBox(height: 16),
              AppTextField(
                label: 'Topic name (Focused)',
                initialValue: 'nas-backup',
                isFocused: true,
                helperText: 'Active focus with cobalt border ring.',
              ),
              SizedBox(height: 16),
              AppTextField(
                label: 'Topic name (Error)',
                initialValue: 'prod db',
                errorText: 'Spaces are not allowed. Try prod-db.',
              ),
              SizedBox(height: 16),
              AppTextField(
                label: 'Endpoint (Disabled)',
                initialValue: 'https://api.critalarm.app/t/prod-db',
                enabled: false,
                helperText: 'Generated from topic name.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChipsAndBadgesSection(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority Chips & Badges',
          style: AppTypography.headline(colors.onCanvas),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Radii.xlAll,
            boxShadow: AppShadows.lightSm,
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  AppPriorityChip(priority: PriorityLevel.min),
                  AppPriorityChip(priority: PriorityLevel.low),
                  AppPriorityChip(priority: PriorityLevel.defaultPriority),
                  AppPriorityChip(priority: PriorityLevel.high),
                  AppPriorityChip(
                    priority: PriorityLevel.critical,
                    isSelected: true,
                  ),
                  AppTopicChip(text: 'POST /t/prod-db'),
                ],
              ),
              SizedBox(height: 24),
              AppBadge(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToastsSection(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Toasts', style: AppTypography.headline(colors.onCanvas)),
        const SizedBox(height: 18),
        const Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            AppToast(
              variant: AppToastVariant.ack,
              message: 'Acknowledged',
              boldText: 'prod-db',
              boldTextSuffix: 'at 03:14',
            ),
            AppToast(
              variant: AppToastVariant.crit,
              boldText: 'nas-backup',
              boldTextSuffix: 'escalated to your second device',
            ),
            AppToast(
              message: 'Endpoint copied to clipboard',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildListRowsSection(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('List Rows', style: AppTypography.headline(colors.onCanvas)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.cream,
            borderRadius: Radii.xlAll,
          ),
          child: Column(
            children: [
              AppListRow(
                name: 'prod-db',
                meta: 'Primary database down. Ringing 2 min 14 s.',
                faceState: FaceState.alarmed,
                isCrit: true,
                trailing: const AppPriorityChip(
                  priority: PriorityLevel.critical,
                ),
                onTap: () {},
              ),
              const SizedBox(height: 8),
              AppListRow(
                name: 'nas-backup',
                meta: 'Finished with 2 warnings',
                faceState: FaceState.worried,
                trailing: const AppPriorityChip(priority: PriorityLevel.high),
                timeText: '02:04',
                onTap: () {},
              ),
              const SizedBox(height: 8),
              AppListRow(
                name: 'uptime-kuma',
                meta: '3 messages today, all default',
                timeText: '08:30',
                onTap: () {},
              ),
              const SizedBox(height: 8),
              AppListRow(
                name: 'home-ha',
                meta: 'Quiet since yesterday',
                isQuiet: true,
                trailing: const AppPriorityChip(priority: PriorityLevel.low),
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSoundRowsSection(AppColors colors) {
    List<double> peaks(double Function(double t) shape) => [
      for (var i = 0; i < 48; i++) shape(i / 48).clamp(0.06, 1).toDouble(),
    ];
    final pager = peaks((t) => (t * 8).floor().isOdd ? .2 : .95);
    final song = peaks((t) => .55 + .45 * math.sin(t * 9 + 1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sound Rows', style: AppTypography.headline(colors.onCanvas)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.cream,
            borderRadius: Radii.xlAll,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppRadioRow(
                title: 'Pager beep',
                meta: '0:14',
                selected: true,
                leading: AppPreviewButton(
                  isPlaying: false,
                  playLabel: 'Play preview',
                  stopLabel: 'Stop preview',
                  onPressed: () {},
                ),
                waveform: WaveformBars(peaks: pager),
                onTap: () {},
              ),
              const SizedBox(height: 8),
              AppRadioRow(
                title: 'Mr Brightside (live)',
                meta: '0:29',
                selected: false,
                note: 'Notifications only',
                leading: AppPreviewButton(
                  isPlaying: true,
                  progress: 0.4,
                  progressLabel: '40 percent played',
                  playLabel: 'Play preview',
                  stopLabel: 'Stop preview',
                  onPressed: () {},
                ),
                waveform: WaveformBars(peaks: song, progress: 0.4),
                onTap: () {},
              ),
              const SizedBox(height: 8),
              AppRadioRow(
                title: 'Siren',
                meta: '0:08',
                selected: false,
                leading: AppPreviewButton(
                  isPlaying: false,
                  playLabel: 'Play preview',
                  stopLabel: 'Stop preview',
                  onPressed: () {},
                ),
                waveform: const WaveformBars(peaks: [], loading: true),
                onTap: () {},
              ),
              const SizedBox(height: 16),
              const SizedBox(
                height: 22,
                child: WaveformBars(peaks: []),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCodeBlockSection(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Code Block', style: AppTypography.headline(colors.onCanvas)),
        const SizedBox(height: 18),
        const AppCodeBlock(
          code:
              '# from the uptime-kuma webhook, or any shell\n'
              'curl -X POST https://api.critalarm.app/t/prod-db \\\n'
              '  -H "Authorization: Bearer ca_live_7Hq2mN9xPz4wKd8" \\\n'
              '  -H "Priority: critical" \\\n'
              '  -d "pg_isready failed 3 times in 90 s"',
        ),
      ],
    );
  }

  Widget _buildEmptyStateSection(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Empty State', style: AppTypography.headline(colors.onCanvas)),
        const SizedBox(height: 18),
        AppEmptyState(
          onButtonPressed: () {},
        ),
      ],
    );
  }

  Widget _buildControlsAndCardsSection(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Switches, Key-Values, & Messages',
          style: AppTypography.headline(colors.onCanvas),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 480,
              child: Column(
                children: [
                  AppToggleRow(
                    title: 'Ring through silent mode',
                    subtitle: 'Repeats every 30 s until acknowledged',
                    value: _toggleVal1,
                    onChanged: (val) => setState(() => _toggleVal1 = val),
                  ),
                  const SizedBox(height: 12),
                  AppToggleRow(
                    title: 'Quiet hours',
                    subtitle: '22:00 to 07:00 (default stays silent)',
                    value: _toggleVal2,
                    onChanged: (val) => setState(() => _toggleVal2 = val),
                  ),
                  const SizedBox(height: 12),
                  const AppKeyValueRow(
                    label: 'Endpoint',
                    value: 'https://api.critalarm.app/t/prod-db',
                    showCopyButton: true,
                  ),
                  const SizedBox(height: 12),
                  const AppKeyValueRow(
                    label: 'Bearer token',
                    value: 'ca_live_7Hq2mN9xPz4wKd8',
                    showCopyButton: true,
                  ),
                ],
              ),
            ),
            const SizedBox(
              width: 480,
              child: Column(
                children: [
                  AppMessageCard(
                    title: 'Backup finished with 2 warnings',
                    timestamp: '02:04',
                    body:
                        'rsync: 2 files vanished during transfer. '
                        '412 GB copied in 43 min.',
                    source: 'cron@nas / high',
                    isHigh: true,
                  ),
                  SizedBox(height: 12),
                  AppNotificationCard(
                    topic: 'prod-db',
                    title: 'Primary database down',
                    body:
                        'pg_isready failed 3 times in 90 s. '
                        'Replica promoted on db-2.',
                    ringingPillText:
                        'Ringing through silent mode. Tap to acknowledge.',
                    isCrit: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriorityLadderSection(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'The Priority Ladder',
          style: AppTypography.headline(colors.onCanvas),
        ),
        const SizedBox(height: 18),
        const Column(
          children: [
            AppLadderRow(
              priority: PriorityLevel.min,
              description: 'Stored in history. No notification at all.',
              faceState: FaceState.calm,
            ),
            SizedBox(height: 8),
            AppLadderRow(
              priority: PriorityLevel.low,
              description: 'Silent notification. No sound, no vibration.',
              faceState: FaceState.calm,
            ),
            SizedBox(height: 8),
            AppLadderRow(
              priority: PriorityLevel.defaultPriority,
              description:
                  'Standard notification with sound. Respects quiet hours.',
              faceState: FaceState.watching,
            ),
            SizedBox(height: 8),
            AppLadderRow(
              priority: PriorityLevel.high,
              description:
                  'Sound and vibration. Shows on lock screen in quiet hours.',
              faceState: FaceState.worried,
            ),
            SizedBox(height: 8),
            AppLadderRow(
              priority: PriorityLevel.critical,
              description:
                  'Alarm. Rings through silent mode and repeats every 30 s.',
              faceState: FaceState.alarmed,
              isCrit: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlarmPreviewSection(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alarm Ringing Experience',
          style: AppTypography.headline(colors.onCanvas),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: colors.critCanvas,
            borderRadius: Radii.xlAll,
          ),
          child: Column(
            children: [
              PulseRingWidget(
                size: 200,
                color: colors.ink.withValues(alpha: 0.2),
                child: FaceWidget(
                  state: FaceState.alarmed,
                  size: 200,
                  isLive: true,
                  overrideStrokeColor: colors.ink,
                  overrideFillColor: colors.critCanvas,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'CRITICAL',
                style: TextStyle(
                  fontFamily: AppTypography.fontDisplay,
                  fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: colors.ink,
                  letterSpacing: -0.04 * 52,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'prod-db',
                style: AppTypography.monoBold(colors.ink, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'Ringing 2 min 14 s. Repeats every 30 s.',
                style: AppTypography.body(colors.ink).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AppSheet(
                  child: Column(
                    children: [
                      Text(
                        'Primary database down',
                        style: AppTypography.title(colors.ink),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'pg_isready failed 3 times in 90 s. '
                        'Replica promoted to primary on db-2.',
                        style: AppTypography.body(colors.ink2),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      AppButton(
                        label: 'Acknowledge',
                        size: AppButtonSize.lg,
                        isFullWidth: true,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
