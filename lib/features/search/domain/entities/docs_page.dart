import 'package:flutter/foundation.dart';

/// One page of the documentation on critalarm.app.
///
/// The app ships a small index of these so documentation is searchable offline.
/// Tapping one opens the real page in a browser.
@immutable
class DocsPage {
  const DocsPage({
    required this.slug,
    required this.title,
    required this.description,
    required this.group,
    required this.url,
  });

  factory DocsPage.fromJson(Map<String, dynamic> json) {
    return DocsPage(
      slug: json['slug'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      group: json['group'] as String? ?? '',
      url: json['url'] as String,
    );
  }

  final String slug;
  final String title;
  final String description;

  /// The sidebar group on the site, drawn as the subtitle so a result reads
  /// "Docker Installation / Installation".
  final String group;

  final String url;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocsPage &&
          runtimeType == other.runtimeType &&
          slug == other.slug;

  @override
  int get hashCode => slug.hashCode;
}
