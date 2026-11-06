import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/auction_settings.dart';
import '../models/bid.dart';
import '../models/item.dart';

/// All Firestore / Auth access lives here so the UI stays simple.
class Repository {
  Repository._();
  static final instance = Repository._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _items => _db.collection('items');
  CollectionReference<Map<String, dynamic>> get _bids => _db.collection('bids');
  DocumentReference<Map<String, dynamic>> get _settings =>
      _db.collection('settings').doc('auction');

  // ---------------------------------------------------------------- auth

  /// Bidders are signed in anonymously so security rules can require auth.
  Future<void> ensureSignedIn() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
  }

  Stream<User?> get authChanges => _auth.authStateChanges();

  Future<void> adminSignIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() async {
    await _auth.signOut();
    await ensureSignedIn();
  }

  /// A user is an admin when a document exists at admins/{uid}.
  /// (Create it by hand in the Firebase console — see README.)
  Stream<bool> isAdmin() => _auth.authStateChanges().asyncExpand((u) {
        if (u == null || u.isAnonymous) return Stream.value(false);
        return _db.collection('admins').doc(u.uid).snapshots().map((d) => d.exists);
      });

  // ------------------------------------------------------------- streams

  Stream<AuctionSettings> settings() =>
      _settings.snapshots().map(AuctionSettings.fromDoc);

  Stream<List<Item>> items() => _items
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(Item.fromDoc).toList());

  Stream<List<Bid>> bids() => _bids
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Bid.fromDoc).toList());

  Future<List<Bid>> allBidsOnce() async {
    final s = await _bids.orderBy('createdAt').get();
    return s.docs.map(Bid.fromDoc).toList();
  }

  Future<List<Item>> allItemsOnce() async {
    final s = await _items.orderBy('createdAt').get();
    return s.docs.map(Item.fromDoc).toList();
  }

  // ------------------------------------------------------------- bidding

  /// Books [quantity] pieces of [itemId] for [bidderName].
  ///
  /// Runs in a transaction so two people can never book the last piece.
  /// Throws [BookingException] with a user-friendly message on failure.
  Future<void> placeBid({
    required String itemId,
    required String bidderName,
    required int quantity,
  }) async {
    final name = bidderName.trim();
    if (name.length < 2) throw BookingException('Please enter your full name.');
    if (quantity < 1) throw BookingException('Quantity must be at least 1.');

    final itemRef = _items.doc(itemId);
    await _db.runTransaction((tx) async {
      final settingsSnap = await tx.get(_settings);
      final settings = AuctionSettings.fromDoc(settingsSnap);
      final now = DateTime.now();
      if (settings.notStarted(now)) {
        throw BookingException('Booking has not started yet.');
      }
      if (!settings.isOpen(now)) {
        throw BookingException('Booking has closed.');
      }

      final itemSnap = await tx.get(itemRef);
      if (!itemSnap.exists) throw BookingException('This item no longer exists.');
      final item = Item.fromDoc(itemSnap);
      if (item.remaining <= 0) {
        throw BookingException('Sorry, "${item.name}" is finished.');
      }
      if (quantity > item.remaining) {
        throw BookingException(
            'Only ${item.remaining} piece(s) of "${item.name}" remain.');
      }

      final bidRef = _bids.doc();
      tx.set(bidRef, {
        'itemId': item.id,
        'itemName': item.name,
        'bidderName': name,
        'quantity': quantity,
        'unitPrice': item.price,
        'uid': _auth.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(itemRef, {
        'remaining': item.remaining - quantity,
        'lastBidId': bidRef.id,
      });
    });
  }

  // --------------------------------------------------------------- admin

  Future<void> saveSettings(AuctionSettings s) => _settings.set({
        'title': s.title,
        'startsAt': s.startsAt == null ? null : Timestamp.fromDate(s.startsAt!),
        'endsAt': s.endsAt == null ? null : Timestamp.fromDate(s.endsAt!),
      });

  Future<void> addItem({
    required String name,
    required String description,
    required String? imageBase64,
    required int quantity,
    required num price,
  }) =>
      _items.add({
        'name': name,
        'description': description,
        'imageBase64': imageBase64,
        'quantity': quantity,
        'remaining': quantity,
        'price': price,
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// Updates an item. Changing the total quantity shifts `remaining` by the
  /// same amount so existing bookings are preserved.
  Future<void> updateItem(
    Item old, {
    required String name,
    required String description,
    required String? imageBase64,
    required int quantity,
    required num price,
  }) =>
      _db.runTransaction((tx) async {
        final ref = _items.doc(old.id);
        final fresh = Item.fromDoc(await tx.get(ref));
        final booked = fresh.quantity - fresh.remaining;
        if (quantity < booked) {
          throw BookingException(
              '$booked piece(s) are already booked; quantity cannot be lower.');
        }
        tx.update(ref, {
          'name': name,
          'description': description,
          'imageBase64': imageBase64,
          'quantity': quantity,
          'remaining': quantity - booked,
          'price': price,
        });
      });

  Future<void> deleteItem(String id) => _items.doc(id).delete();

  Future<void> deleteBid(Bid bid) => _db.runTransaction((tx) async {
        // Return the pieces to stock when an admin cancels a booking.
        final itemRef = _items.doc(bid.itemId);
        final itemSnap = await tx.get(itemRef);
        if (itemSnap.exists) {
          final item = Item.fromDoc(itemSnap);
          tx.update(itemRef, {
            'remaining': (item.remaining + bid.quantity).clamp(0, item.quantity),
          });
        }
        tx.delete(_bids.doc(bid.id));
      });
}

class BookingException implements Exception {
  final String message;
  BookingException(this.message);
  @override
  String toString() => message;
}
