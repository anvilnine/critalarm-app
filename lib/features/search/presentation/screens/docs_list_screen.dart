import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/search/domain/entities/docs_page.dart';
import 'package:critalarm/features/search/domain/usecases/get_docs_index_usecase.dart';
import 'package:critalarm/features/search/presentation/widgets/search_docs_row.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens one docs page, the way a docs search result does.
typedef DocsPageOpener = Future<void> Function(DocsPage page);

Future<void> _openInBrowser(DocsPage page) async {
  try {
    await launchUrl(Uri.parse(page.url), mode: LaunchMode.inAppBrowserView);
  } on Exception {
    // Nothing to recover: the row simply does not navigate.
  }
}

/// The pages by group, groups in the order they first appear.
abstract final class DocsListScreenGrouping {
  static Map<String, List<DocsPage>> of(List<DocsPage> pages) {
    final groups = <String, List<DocsPage>>{};
    for (final page in pages) {
      groups.putIfAbsent(page.group, () => <DocsPage>[]).add(page);
    }
    return groups;
  }
}

/// The docs list under Settings > Help: every page of the bundled docs index,
/// grouped as the site's sidebar groups them, in the index's order. A page
/// opens in the in-app browser.
class DocsListScreen extends StatefulWidget {
  const DocsListScreen({this.load, this.open = _openInBrowser, super.key});

  /// Reads the pages. Defaults to the bundled index; tests pass their own.
  final Future<List<DocsPage>?> Function()? load;

  final DocsPageOpener open;

  @override
  State<DocsListScreen> createState() => _DocsListScreenState();
}

class _DocsListScreenState extends State<DocsListScreen> {
  late final Future<List<DocsPage>?> _pages = _read();

  Future<List<DocsPage>?> _read() async {
    final custom = widget.load;
    if (custom != null) return custom();
    final result = await getIt<GetDocsIndexUsecase>()(const NoParams());
    return result.getOrNull();
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      hasTabBar: false,
      topBar: AppTopBar(
        title: LocaleKeys.docs_list_title.tr(),
        leading: AppIconButton(
          glyph: GlyphType.back,
          ariaLabel: LocaleKeys.common_back.tr(),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: FutureBuilder<List<DocsPage>?>(
            future: _pages,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox.shrink();
              }
              final pages = snapshot.data;
              if (pages == null || pages.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(Spacing.s6),
                  child: Text(
                    LocaleKeys.docs_list_unavailable.tr(),
                    textAlign: TextAlign.center,
                    style: AppTypography.small(context.appColors.ink3),
                  ),
                );
              }
              return _groups(context, DocsListScreenGrouping.of(pages));
            },
          ),
        ),
      ],
    );
  }

  Widget _groups(BuildContext context, Map<String, List<DocsPage>> groups) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final entry in groups.entries) ...<Widget>[
            AppSectionHeader(
              entry.key,
              padding: const EdgeInsets.fromLTRB(20, 14, 4, 6),
            ),
            AppSheet(
              padding: const EdgeInsets.all(6),
              color: colors.cream,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (var i = 0; i < entry.value.length; i++) ...<Widget>[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: ColoredBox(
                          color: colors.hairline,
                          child: const SizedBox(height: 1),
                        ),
                      ),
                    // The group is the heading above, so the row has no
                    // second line.
                    SearchDocsRow(
                      title: entry.value[i].title,
                      group: '',
                      onTap: () => unawaited(widget.open(entry.value[i])),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
