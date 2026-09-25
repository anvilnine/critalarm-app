import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// What the ringing faces are drawn on.
enum RingingBackdrop {
  alarm('Alarm'),
  signature('Signature'),
  plain('Plain');

  const RingingBackdrop(this.label);
  final String label;
}

/// Developer screen for the animated ringing faces: every [RingingStyle] on
/// one page, one of them large, with the speed and backdrop to hand.
class RingingFacesScreen extends StatefulWidget {
  const RingingFacesScreen({super.key});

  @override
  State<RingingFacesScreen> createState() => _RingingFacesScreenState();
}

class _RingingFacesScreenState extends State<RingingFacesScreen> {
  RingingStyle _selected = RingingStyle.panic;
  RingingBackdrop _backdrop = RingingBackdrop.alarm;
  bool _isLive = true;
  double _speed = 1;

  Color _stageColor(AppColors colors) => switch (_backdrop) {
    RingingBackdrop.alarm => colors.critCanvas,
    RingingBackdrop.signature => colors.canvas,
    RingingBackdrop.plain => colors.surface,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppScreenScaffold(
      topBar: AppTopBar(
        title: 'Ringing faces',
        leading: AppIconButton(
          glyph: GlyphType.back,
          ariaLabel: 'Back',
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
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, Spacing.s2, 12, 12),
            child: _stage(colors),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: _controls(colors),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'ALL ${RingingStyle.values.length} STYLES',
              style: TextStyle(
                fontFamily: AppTypography.fontBody,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: colors.ink3,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.crossAxisExtent > 540 ? 4 : 2;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.82,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _card(RingingStyle.values[index], colors),
                  childCount: RingingStyle.values.length,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _stage(AppColors colors) => AppSheet(
    child: Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _stageColor(colors),
            borderRadius: Radii.mdAll,
          ),
          child: Center(
            child: RingingFaceWidget(
              style: _selected,
              size: 240,
              isLive: _isLive,
              speed: _speed,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _selected.label,
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
          _selected.description,
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
            'RingingFaceWidget(style: RingingStyle.${_selected.name})',
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

  Widget _controls(AppColors colors) => AppSheet(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader('Backdrop'),
        AppSegmentedControl<RingingBackdrop>(
          items: RingingBackdrop.values,
          selectedItem: _backdrop,
          labelBuilder: (b) => b.label,
          onChanged: (b) {
            AppHaptics.selection();
            setState(() => _backdrop = b);
          },
        ),
        const SizedBox(height: 16),
        AppToggleRow(
          title: 'Live motion',
          subtitle: 'Play the loops, or hold each on its key frame',
          value: _isLive,
          onChanged: (val) {
            AppHaptics.selection();
            setState(() => _isLive = val);
          },
        ),
        const SizedBox(height: 14),
        const AppSectionHeader('Speed'),
        AppSegmentedControl<double>(
          items: const [0.25, 0.5, 1, 1.5, 2],
          selectedItem: _speed,
          labelBuilder: (s) => '${s == s.roundToDouble() ? s.toInt() : s}x',
          onChanged: (s) {
            AppHaptics.selection();
            setState(() => _speed = s);
          },
        ),
      ],
    ),
  );

  Widget _card(RingingStyle style, AppColors colors) {
    final isSelected = style == _selected;
    return InkWell(
      onTap: () {
        AppHaptics.selection();
        setState(() => _selected = style);
      },
      borderRadius: Radii.mdAll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: Radii.mdAll,
          border: Border.all(
            color: isSelected ? colors.primary : colors.hairline,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected ? AppShadows.lightSm : null,
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: RingingFaceWidget(
                  style: style,
                  size: 104,
                  isLive: _isLive,
                  speed: _speed,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              style.label,
              textAlign: TextAlign.center,
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
