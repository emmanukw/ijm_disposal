import 'package:cloud_firestore/cloud_firestore.dart';

/// Running count of what one person has booked (bidders/{uid}).
/// Used to enforce per-person limits.
class BidderTally {
  final String name;
  final int total;
  final Map<String, int> items; // itemId -> pieces booked

  const BidderTally({this.name = '', this.total = 0, this.items = const {}});

  static const empty = BidderTally();

  int forItem(String itemId) => items[itemId] ?? 0;

  factory BidderTally.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    if (d == null) return empty;
    return BidderTally(
      name: (d['name'] ?? '') as String,
      total: (d['total'] ?? 0) as int,
      items: ((d['items'] ?? const {}) as Map)
          .map((k, v) => MapEntry(k as String, (v as num).toInt())),
    );
  }
}
