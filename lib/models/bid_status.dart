import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin-only payment/collection tracking for one bid (bidStatus/{bidId}).
class BidStatus {
  final bool paid;
  final DateTime? paidAt;
  final bool collected;
  final DateTime? collectedAt;
  final String note; // e.g. M-Pesa reference or receipt number

  const BidStatus({
    this.paid = false,
    this.paidAt,
    this.collected = false,
    this.collectedAt,
    this.note = '',
  });

  static const none = BidStatus();

  factory BidStatus.fromMap(Map<String, dynamic> d) => BidStatus(
    paid: (d['paid'] ?? false) as bool,
    paidAt: (d['paidAt'] as Timestamp?)?.toDate(),
    collected: (d['collected'] ?? false) as bool,
    collectedAt: (d['collectedAt'] as Timestamp?)?.toDate(),
    note: (d['note'] ?? '') as String,
  );
}
