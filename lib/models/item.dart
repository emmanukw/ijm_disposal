import 'package:cloud_firestore/cloud_firestore.dart';

/// A disposed item that bidders can book.
class Item {
  final String id;
  final String name;
  final String description;

  /// Small JPEG thumbnail, base64-encoded (kept in Firestore so no paid
  /// Cloud Storage bucket is needed).
  final String? imageBase64;
  final int quantity; // total pieces offered
  final int remaining; // pieces still available
  final num price; // cost per piece
  final DateTime? createdAt;

  const Item({
    required this.id,
    required this.name,
    required this.description,
    required this.imageBase64,
    required this.quantity,
    required this.remaining,
    required this.price,
    this.createdAt,
  });

  bool get soldOut => remaining <= 0;
  int get booked => quantity - remaining;

  factory Item.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Item(
      id: doc.id,
      name: (d['name'] ?? '') as String,
      description: (d['description'] ?? '') as String,
      imageBase64: d['imageBase64'] as String?,
      quantity: (d['quantity'] ?? 0) as int,
      remaining: (d['remaining'] ?? 0) as int,
      price: (d['price'] ?? 0) as num,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
