import 'package:cloud_firestore/cloud_firestore.dart';

/// One booking/bid placed by a bidder on an item.
class Bid {
  final String id;
  final String itemId;
  final String itemName;
  final String bidderName;
  final int quantity;
  final num unitPrice;
  final DateTime? createdAt;

  const Bid({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.bidderName,
    required this.quantity,
    required this.unitPrice,
    required this.createdAt,
  });

  num get total => unitPrice * quantity;

  factory Bid.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Bid(
      id: doc.id,
      itemId: (d['itemId'] ?? '') as String,
      itemName: (d['itemName'] ?? '') as String,
      bidderName: (d['bidderName'] ?? '') as String,
      quantity: (d['quantity'] ?? 0) as int,
      unitPrice: (d['unitPrice'] ?? 0) as num,
      // serverTimestamp is null locally until the server confirms the write.
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
