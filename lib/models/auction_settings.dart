import 'package:cloud_firestore/cloud_firestore.dart';

/// Global settings for the current disposal exercise (stored at settings/auction).
class AuctionSettings {
  final String title;
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// Max pieces one person may book of a single item (0 = no limit).
  final int maxPerItemPerPerson;

  /// Max pieces one person may book across all items (0 = no limit).
  final int maxTotalPerPerson;

  const AuctionSettings({
    required this.title,
    this.startsAt,
    this.endsAt,
    this.maxPerItemPerPerson = 0,
    this.maxTotalPerPerson = 0,
  });

  static const empty = AuctionSettings(title: 'IJM Disposal of Items');

  bool isOpen(DateTime now) =>
      endsAt != null &&
      now.isBefore(endsAt!) &&
      (startsAt == null || !now.isBefore(startsAt!));

  bool notStarted(DateTime now) => startsAt != null && now.isBefore(startsAt!);

  bool get hasLimits => maxPerItemPerPerson > 0 || maxTotalPerPerson > 0;

  /// Human-readable summary, e.g. "Max 2 per item · 5 in total per person".
  String get limitsText {
    final parts = <String>[
      if (maxPerItemPerPerson > 0) 'max $maxPerItemPerPerson per item',
      if (maxTotalPerPerson > 0) '$maxTotalPerPerson in total',
    ];
    if (parts.isEmpty) return 'No booking limits';
    final s = parts.join(' · ');
    return '${s[0].toUpperCase()}${s.substring(1)} per person';
  }

  factory AuctionSettings.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    if (d == null) return empty;
    return AuctionSettings(
      title: (d['title'] ?? empty.title) as String,
      startsAt: (d['startsAt'] as Timestamp?)?.toDate(),
      endsAt: (d['endsAt'] as Timestamp?)?.toDate(),
      maxPerItemPerPerson: (d['maxPerItemPerPerson'] ?? 0) as int,
      maxTotalPerPerson: (d['maxTotalPerPerson'] ?? 0) as int,
    );
  }
}
