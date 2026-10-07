import 'package:flutter/foundation.dart';

/// What the user told the app about the maker steps. The app cannot read
/// these settings, so this is the user's word and nothing more.
@immutable
final class MakerGuideRecord {
  const MakerGuideRecord({this.doneAt, this.osMajor});

  /// Nothing marked.
  static const none = MakerGuideRecord();

  /// When the user tapped "I did these". Null if they have not.
  final DateTime? doneAt;

  /// The OS major version at that moment, or null if the phone could not
  /// say. A phone update often puts these settings back, so a different
  /// version later voids the word.
  final int? osMajor;

  bool get isDone => doneAt != null;

  @override
  bool operator ==(Object other) =>
      other is MakerGuideRecord &&
      other.doneAt == doneAt &&
      other.osMajor == osMajor;

  @override
  int get hashCode => Object.hash(doneAt, osMajor);
}

abstract interface class MakerGuideStore {
  MakerGuideRecord read();
  Future<void> write(MakerGuideRecord record);
}
