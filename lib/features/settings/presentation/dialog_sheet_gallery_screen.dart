import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Dev-only preview of the dialog and bottom-sheet library. Reachable from
/// Developer options. Every row opens a variant and toasts the value it
/// returns, so the result types can be read at a glance.
class DialogSheetGalleryScreen extends StatelessWidget {
  const DialogSheetGalleryScreen({super.key});

  void _toast(
    BuildContext context,
    String message, {
    AppToastVariant variant = AppToastVariant.ack,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Center(
          child: AppToast(message: message, variant: variant),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String name,
    String meta,
    VoidCallback onTap,
  ) {
    return AppListRow(
      name: name,
      meta: meta,
      faceState: null,
      trailing: AppGlyph(
        GlyphType.arrow,
        color: context.appColors.ink3,
        size: 16,
      ),
      onTap: onTap,
    );
  }

  Future<void> _confirm(BuildContext context) async {
    AppHaptics.capture();
    final result = await showAppDialog<bool>(
      context: context,
      kicker: 'CONFIRM',
      title: 'Disconnect server?',
      body: 'You will stop receiving pages until you connect again.',
      actions: const [
        AppDialogAction(
          label: 'Cancel',
          value: false,
          variant: AppButtonVariant.ghost,
        ),
        AppDialogAction(label: 'Disconnect', value: true),
      ],
    );
    if (!context.mounted) return;
    _toast(context, 'Result: $result');
  }

  Future<void> _destructive(BuildContext context) async {
    AppHaptics.capture();
    final result = await showAppDialog<bool>(
      context: context,
      kicker: 'DESTRUCTIVE',
      title: 'Delete topic?',
      body:
          'payments-api and its history are gone forever. Tokens stop '
          'working.',
      actions: const [
        AppDialogAction(
          label: 'Keep',
          value: false,
          variant: AppButtonVariant.ghost,
        ),
        AppDialogAction(
          label: 'Delete',
          value: true,
          variant: AppButtonVariant.crit,
        ),
      ],
    );
    if (!context.mounted) return;
    _toast(context, 'Result: $result');
  }

  Future<void> _inputDialog(BuildContext context) async {
    AppHaptics.capture();
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: AppDialog(
          kicker: 'EDIT SERVER',
          title: 'Connect a server',
          content: AppTextField(
            label: 'SERVER URL',
            controller: controller,
            placeholder: 'https://api.critalarm.app',
          ),
          actions: [
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            AppButton(
              label: 'Save',
              size: AppButtonSize.sm,
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (!context.mounted) return;
    _toast(context, 'Saved: ${result?.isEmpty == false ? result : '(empty)'}');
  }

  Future<void> _faceDialog(BuildContext context) async {
    AppHaptics.capture();
    final result = await showAppDialog<String>(
      context: context,
      leading: const FaceWidget(state: FaceState.alarmed, size: 48),
      title: 'Acknowledge prod-db?',
      body: 'Ringing through silent mode. Tap to stop the alarm.',
      actions: const [
        AppDialogAction(
          label: 'Later',
          value: 'later',
          variant: AppButtonVariant.ghost,
        ),
        AppDialogAction(label: 'Acknowledge', value: 'ack'),
      ],
    );
    if (!context.mounted) return;
    _toast(context, 'Result: $result');
  }

  Future<void> _spotlight(BuildContext context) async {
    AppHaptics.capture();
    final result = await showAppDialog<String>(
      context: context,
      kicker: 'STEP 1 OF 3',
      title: 'One alarm line per topic',
      body:
          'A topic is one alarm line. Your server sends it a message and '
          'your phone rings.\n'
          '• Calm face: all quiet\n'
          '• Red, alarmed face: ringing now',
      skin: AppDialogSkin.panel,
      alignActions: MainAxisAlignment.spaceBetween,
      actions: const [
        AppDialogAction(
          label: 'Back',
          value: 'back',
          variant: AppButtonVariant.ghost,
        ),
        AppDialogAction(label: 'Next', value: 'next'),
      ],
    );
    if (!context.mounted) return;
    _toast(context, 'Result: $result');
  }

  Future<void> _multiOption(BuildContext context) async {
    AppHaptics.capture();
    final result = await showAppSheet<int>(
      context: context,
      title: 'Ring every',
      subtitle: 'How long before the alarm repeats',
      options: const [
        AppSheetOption(label: '30 seconds', value: 30, isSelected: true),
        AppSheetOption(label: '1 minute', value: 60),
        AppSheetOption(label: '5 minutes', value: 300),
        AppSheetOption(label: 'Never', value: 0),
      ],
    );
    if (!context.mounted) return;
    _toast(context, 'Result: $result');
  }

  Future<void> _actionList(BuildContext context) async {
    AppHaptics.capture();
    final result = await showAppSheet<String>(
      context: context,
      title: 'payments-api',
      options: const [
        AppSheetOption(
          label: 'Copy endpoint',
          value: 'copy',
          glyph: GlyphType.copy,
        ),
        AppSheetOption(
          label: 'Critical delivery',
          value: 'critical',
          glyph: GlyphType.gear,
        ),
        AppSheetOption(
          label: 'Delete topic',
          value: 'delete',
          glyph: GlyphType.close,
          isDestructive: true,
        ),
      ],
    );
    if (!context.mounted) return;
    _toast(context, 'Result: $result');
  }

  Future<void> _inputSheet(BuildContext context) async {
    AppHaptics.capture();
    final controller = TextEditingController();
    final result = await showAppSheet<String>(
      context: context,
      title: 'Create a topic',
      subtitle: 'Lowercase, digits, hyphens. This becomes the URL.',
      content: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(controller: controller, placeholder: 'prod-db'),
          const SizedBox(height: 16),
          AppButton(
            label: 'Create',
            isFullWidth: true,
            onPressed: () =>
                Navigator.of(sheetContext).pop(controller.text.trim()),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!context.mounted) return;
    _toast(
      context,
      'Created: ${result?.isEmpty == false ? result : '(empty)'}',
    );
  }

  Future<void> _expanding(BuildContext context) async {
    AppHaptics.capture();
    final result = await showExpandingSheet<String>(
      context: context,
      title: 'Message detail',
      subtitle: 'Drag the handle to expand',
      content: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(
            context,
            'pg_isready failed 3 times in 90 s. Replica '
            'promoted on db-2.',
          ),
          _line(context, 'Source: cron@prod / critical'),
          _line(context, 'Token: ca_live_7Hq2mN9xPz4wKd8'),
          const SizedBox(height: 8),
          AppButton(
            label: 'Acknowledge',
            isFullWidth: true,
            onPressed: () => Navigator.of(sheetContext).pop('ack'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    _toast(context, 'Result: $result');
  }

  Widget _line(BuildContext context, String text) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: Radii.mdAll,
      ),
      child: Text(
        text,
        style: AppTypography.body(colors.ink2, fontSize: 13),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      topBar: AppTopBar(
        title: 'Dialogs & bottom sheets',
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
            padding: const EdgeInsets.fromLTRB(12, Spacing.s2, 12, 16),
            child: AppSheet(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppSectionHeader('Dialogs'),
                  _row(context, 'Confirm', 'Yes / no', () => _confirm(context)),
                  const SizedBox(height: 8),
                  _row(
                    context,
                    'Destructive',
                    'Crit action',
                    () => _destructive(context),
                  ),
                  const SizedBox(height: 8),
                  _row(
                    context,
                    'With input',
                    'Text field',
                    () => _inputDialog(context),
                  ),
                  const SizedBox(height: 8),
                  _row(
                    context,
                    'With face',
                    'Leading face',
                    () => _faceDialog(context),
                  ),
                  const SizedBox(height: 8),
                  _row(
                    context,
                    'Spotlight',
                    'Panel skin',
                    () => _spotlight(context),
                  ),
                  const SizedBox(height: 14),
                  const AppSectionHeader('Bottom sheets'),
                  _row(
                    context,
                    'Multi-option',
                    'Single-select',
                    () => _multiOption(context),
                  ),
                  const SizedBox(height: 8),
                  _row(
                    context,
                    'Action list',
                    'Destructive last',
                    () => _actionList(context),
                  ),
                  const SizedBox(height: 8),
                  _row(
                    context,
                    'With input',
                    'Text field + action',
                    () => _inputSheet(context),
                  ),
                  const SizedBox(height: 8),
                  _row(
                    context,
                    'Auto-expanding',
                    'Peek, then drag to full',
                    () => _expanding(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
