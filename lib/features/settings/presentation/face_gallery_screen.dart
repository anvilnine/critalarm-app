import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Palette modes for testing face character expressions.
enum FacePaletteMode {
  screenshot('Screenshot'),
  yellow('Signature'),
  severity('Severity');

  const FacePaletteMode(this.label);
  final String label;
}

/// Developer screen demoing and showcasing all character faces of the app,
/// including the 8 newly designed vector expressions (Shocked, Laughing,
/// Surprised, Skeptical, Dizzy, Determined, Confused, Sad).
class FaceGalleryScreen extends StatefulWidget {
  const FaceGalleryScreen({super.key});

  @override
  State<FaceGalleryScreen> createState() => _FaceGalleryScreenState();
}

class _FaceGalleryScreenState extends State<FaceGalleryScreen> {
  /// The faces, in the order the expression sheets lay them out. Every state
  /// appears in exactly one group, so nothing is left out of the gallery.
  static const List<_FaceGroup> _groups = [
    _FaceGroup('APP FACES', [
      FaceState.calm,
      FaceState.watching,
      FaceState.worried,
      FaceState.alarmed,
      FaceState.acked,
      FaceState.working,
      FaceState.success,
    ]),
    _FaceGroup('CORE', [
      FaceState.blink,
      FaceState.happy,
      FaceState.content,
      FaceState.curious,
      FaceState.lookLeft,
      FaceState.lookRight,
      FaceState.love,
    ]),
    _FaceGroup('THINKING', [
      FaceState.thinking,
      FaceState.interested,
      FaceState.realization,
      FaceState.surprised,
      FaceState.concerned,
      FaceState.confused,
      FaceState.skeptical,
    ]),
    _FaceGroup('TIRED AND RESTING', [
      FaceState.yawn,
      FaceState.sleepy,
      FaceState.dozing,
      FaceState.wakesUp,
      FaceState.shakeHead,
      FaceState.breatheIn,
      FaceState.breatheOut,
    ]),
    _FaceGroup('BIG FEELINGS', [
      FaceState.laughing,
      FaceState.proud,
      FaceState.cheeky,
      FaceState.confident,
      FaceState.determined,
      FaceState.shocked,
      FaceState.dizzy,
      FaceState.sad,
    ]),
  ];

  FaceState _selectedFace = FaceState.laughing;

  /// Set when a ringing face is picked, which the hero then shows instead
  /// of [_selectedFace].
  RingingStyle? _selectedRinging;
  FacePaletteMode _paletteMode = FacePaletteMode.screenshot;
  bool _isLive = true;
  double _customTiltDegrees = 0;
  bool _useNaturalTilt = true;
  double _previewSize = 120;

  Color _resolveFillColor(FaceState state, AppColors colors) {
    return switch (_paletteMode) {
      FacePaletteMode.screenshot => state.characteristicColor,
      FacePaletteMode.yellow => colors.faceFill,
      FacePaletteMode.severity => switch (state) {
        FaceState.alarmed || FaceState.shocked => colors.critCanvas,
        FaceState.worried => colors.highCanvas,
        FaceState.acked => colors.ackCanvas,
        _ => colors.faceFill,
      },
    };
  }

  Color? _resolveStrokeColor(FaceState state, AppColors colors) {
    if (_paletteMode == FacePaletteMode.severity) {
      return switch (state) {
        FaceState.alarmed || FaceState.shocked => colors.crit,
        FaceState.worried => colors.high,
        FaceState.acked => colors.cobalt,
        _ => colors.faceStroke,
      };
    }
    return null;
  }

  double _getEffectiveTilt(FaceState state) {
    if (_useNaturalTilt) {
      return state.defaultTilt;
    }
    return _customTiltDegrees * math.pi / 180;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppScreenScaffold(
      topBar: AppTopBar(
        title: 'Face expressions',
        leading: AppIconButton(
          glyph: GlyphType.back,
          ariaLabel: LocaleKeys.common_back.tr(),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings/developer');
            }
          },
        ),
      ),
      slivers: [
        // Hero stage for the currently selected face
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, Spacing.s2, 12, 12),
            child: _buildHeroStage(colors),
          ),
        ),

        // Interactive controls sheet
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: AppSheet(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionHeader('Palette mode'),
                  AppSegmentedControl<FacePaletteMode>(
                    items: FacePaletteMode.values,
                    selectedItem: _paletteMode,
                    labelBuilder: (mode) => mode.label,
                    onChanged: (mode) {
                      AppHaptics.selection();
                      setState(() => _paletteMode = mode);
                    },
                  ),
                  const SizedBox(height: 16),
                  AppToggleRow(
                    title: 'Live motion',
                    subtitle: 'Animate eyes, jitters, bounce & drift',
                    value: _isLive,
                    onChanged: (val) {
                      AppHaptics.selection();
                      setState(() => _isLive = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  const AppSectionHeader('Head tilt expression'),
                  Row(
                    children: [
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final naturalDeg =
                                (_selectedFace.defaultTilt * 180 / math.pi)
                                    .round();
                            final customDeg = _customTiltDegrees.round();
                            final tiltLabel = _useNaturalTilt
                                ? 'Natural tilt ($naturalDeg°)'
                                : 'Custom angle ($customDeg°)';
                            return Text(
                              tiltLabel,
                              style: TextStyle(
                                fontFamily: AppTypography.fontBody,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.ink,
                              ),
                            );
                          },
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          AppHaptics.selection();
                          setState(() {
                            _useNaturalTilt = !_useNaturalTilt;
                            if (!_useNaturalTilt) {
                              _customTiltDegrees =
                                  _selectedFace.defaultTilt * 180 / math.pi;
                            }
                          });
                        },
                        child: Text(
                          _useNaturalTilt ? 'Manual tilt' : 'Reset to natural',
                          style: TextStyle(
                            fontFamily: AppTypography.fontBody,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_useNaturalTilt) ...[
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: colors.primary,
                        thumbColor: colors.primary,
                        inactiveTrackColor: colors.hairline,
                      ),
                      child: Slider(
                        value: _customTiltDegrees,
                        min: -25,
                        max: 25,
                        divisions: 50,
                        label: '${_customTiltDegrees.round()}°',
                        onChanged: (val) {
                          setState(() => _customTiltDegrees = val);
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const AppSectionHeader('Preview size'),
                  AppSegmentedControl<double>(
                    items: const [120, 64, 36, 28],
                    selectedItem: _previewSize,
                    labelBuilder: (size) => '${size.toInt()}px',
                    onChanged: (val) {
                      AppHaptics.selection();
                      setState(() => _previewSize = val);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        for (final group in _groups) ...[
          _groupHeader(group, colors),
          _groupGrid(group, colors),
        ],
        _ringingHeader(colors),
        _ringingGrid(colors),
      ],
    );
  }

  Widget _groupHeader(_FaceGroup group, AppColors colors) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Text(
            group.title,
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: colors.ink3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: colors.hairline,
              borderRadius: Radii.smAll,
            ),
            child: Text(
              '${group.faces.length} faces',
              style: TextStyle(
                fontFamily: AppTypography.fontBody,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.ink2,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _groupGrid(_FaceGroup group, AppColors colors) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
    sliver: SliverLayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.crossAxisExtent > 540 ? 4 : 2;
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.88,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final face = group.faces[index];
              return _buildFaceCard(
                face,
                _selectedRinging == null && face == _selectedFace,
                colors,
              );
            },
            childCount: group.faces.length,
          ),
        );
      },
    ),
  );

  Widget _ringingHeader(AppColors colors) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Text(
            'RINGING',
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: colors.ink3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colors.hairline,
              borderRadius: Radii.smAll,
            ),
            child: Text(
              '${RingingStyle.values.length} faces',
              style: TextStyle(
                fontFamily: AppTypography.fontBody,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.ink2,
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => context.push('/settings/developer/ringing-faces'),
            child: Text(
              'Open lab',
              style: TextStyle(
                fontFamily: AppTypography.fontBody,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _ringingGrid(AppColors colors) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
    sliver: SliverLayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.crossAxisExtent > 540 ? 4 : 2;
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.88,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final style = RingingStyle.values[index];
              return _buildCard(
                isSelected: style == _selectedRinging,
                label: style.label,
                colors: colors,
                onTap: () => setState(() => _selectedRinging = style),
                face: RingingFaceWidget(
                  style: style,
                  size: 88,
                  isLive: _isLive,
                ),
              );
            },
            childCount: RingingStyle.values.length,
          ),
        );
      },
    ),
  );

  Widget _buildHeroStage(AppColors colors) {
    final ringing = _selectedRinging;
    if (ringing != null) return _buildRingingHero(ringing, colors);
    final tilt = _getEffectiveTilt(_selectedFace);
    final fill = _resolveFillColor(_selectedFace, colors);
    final stroke = _resolveStrokeColor(_selectedFace, colors);

    return AppSheet(
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: FaceWidget(
              state: _selectedFace,
              size: _previewSize,
              isLive: _isLive,
              tiltAngle: tilt,
              overrideFillColor: fill,
              overrideStrokeColor: stroke,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFace.label,
            style: TextStyle(
              fontFamily: AppTypography.fontDisplay,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _selectedFace.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontSize: 13,
              color: colors.ink2,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.cream,
              borderRadius: Radii.smAll,
            ),
            child: SelectableText(
              'FaceWidget(state: FaceState.${_selectedFace.name})',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: colors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildRingingHero(RingingStyle style, AppColors colors) {
    // The palette modes pick a head colour per expression; a ringing face is
    // always the alarm, so only the screenshot mode keeps its own yellow.
    final fill = _paletteMode == FacePaletteMode.severity
        ? colors.critCanvas
        : null;
    return AppSheet(
      child: Column(
        children: [
          Center(
            child: RingingFaceWidget(
              style: style,
              size: _previewSize * 1.6,
              isLive: _isLive,
              fillColor: fill,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            style.label,
            style: TextStyle(
              fontFamily: AppTypography.fontDisplay,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            style.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontSize: 13,
              color: colors.ink2,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.cream,
              borderRadius: Radii.smAll,
            ),
            child: SelectableText(
              'RingingFaceWidget(style: RingingStyle.${style.name})',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: colors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildFaceCard(
    FaceState face,
    bool isSelected,
    AppColors colors,
  ) {
    final tilt = _getEffectiveTilt(face);
    final fill = _resolveFillColor(face, colors);
    final stroke = _resolveStrokeColor(face, colors);

    return _buildCard(
      isSelected: isSelected,
      label: face.label,
      colors: colors,
      onTap: () => setState(() {
        _selectedFace = face;
        _selectedRinging = null;
        if (_useNaturalTilt) {
          _customTiltDegrees = face.defaultTilt * 180 / math.pi;
        }
      }),
      face: FaceWidget(
        state: face,
        size: 68,
        isLive: _isLive,
        tiltAngle: tilt,
        overrideFillColor: fill,
        overrideStrokeColor: stroke,
      ),
    );
  }

  /// One tappable card in a grid: a face over its name.
  Widget _buildCard({
    required bool isSelected,
    required String label,
    required AppColors colors,
    required VoidCallback onTap,
    required Widget face,
  }) {
    return InkWell(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      borderRadius: Radii.mdAll,
      child: AnimatedContainer(
        duration: context.motion(const Duration(milliseconds: 180)),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: Radii.mdAll,
          border: Border.all(
            color: isSelected ? colors.primary : colors.hairline,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected ? AppShadows.lightSm : null,
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: Center(child: face)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTypography.fontBody,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: isSelected ? colors.primary : colors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One titled row of faces in the gallery.
class _FaceGroup {
  const _FaceGroup(this.title, this.faces);

  /// The heading above the grid.
  final String title;

  /// What is in it.
  final List<FaceState> faces;
}
