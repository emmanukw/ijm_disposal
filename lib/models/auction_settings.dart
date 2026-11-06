import 'package:cloud_firestore/cloud_firestore.dart';

/// Global settings for the current disposal exercise (stored at settings/auction).
class AuctionSettings {
  final String title;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const AuctionSettings({required this.title, this.startsAt, this.endsAt});

  static const empty = AuctionSettings(title: 'IJM Disposal of Items');

  bool isOpen(DateTime now) =>
      endsAt != null &&
      now.isBefore(endsAt!) &&
      (startsAt == null || !now.isBefore(startsAt!));

  bool notStarted(DateTime now) => startsAt != null && now.isBefore(startsAt!);

  factory AuctionSettings.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    if (d == null) return empty;
    return AuctionSettings(
      title: (d['title'] ?? empty.title) as String,
      startsAt: (d['startsAt'] as Timestamp?)?.toDate(),
      endsAt: (d['endsAt'] as Timestamp?)?.toDate(),
    );
  }
}
