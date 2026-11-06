import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config.dart';
import '../models/auction_settings.dart';
import '../models/bid.dart';
import '../models/bid_status.dart';
import '../models/bidder_tally.dart';
import '../models/item.dart';

/// All Firestore / Auth access lives here so the UI stays simple.
class Repository {
  Repository._();
  static final instance = Repository._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _items => _db.collection('items');
  CollectionReference<Map<String, dynamic>> get _bids => _db.collection('bids');
  CollectionReference<Map<String, dynamic>> get _status => _db.collection('bidStatus');
  CollectionReference<Map<String, dynamic>> get _bidders => _db.collection('bidders');
  DocumentReference<Map<String, dynamic>> get _settings =>
      _db.collection('settings').doc('auction');

  // ---------------------------------------------------------------- auth

  ActionCodeSettings get _continueTo =>
      ActionCodeSettings(url: '${Uri.base.origin}/', handleCodeInApp: false);

  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  /// Creates a staff account and sends the verification email.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!isAllowedEmail(email)) {
      throw AuthMessage('Please use your @$allowedEmailDomain email address.');
    }
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    await cred.user!.updateDisplayName(name.trim());
    await cred.user!.sendEmailVerification(_continueTo);
  }

  Future<void> resendVerification() async =>
      _auth.currentUser?.sendEmailVerification(_continueTo);

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim(), actionCodeSettings: _continueTo);

  Future<void> signOut() => _auth.signOut();

  String? get currentUid => _auth.currentUser?.uid;

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

  /// What the signed-in user has booked so far (for limits).
  Stream<BidderTally> myTally() {
    final uid = currentUid;
    if (uid == null) return Stream.value(BidderTally.empty);
    return _bidders.doc(uid).snapshots().map(BidderTally.fromDoc);
  }

  /// Admin only: paid/collected status for every bid, keyed by bid id.
  Stream<Map<String, BidStatus>> bidStatuses() => _status.snapshots().map(
      (s) => {for (final d in s.docs) d.id: BidStatus.fromMap(d.data())});

  // ------------------------------------------------------------- bidding

  /// Books [quantity] pieces of [itemId] for the signed-in staff member.
  ///
  /// Runs in a transaction so two people can never book the last piece, and
  /// keeps the per-person tally used to enforce booking limits.
  /// Throws [BookingException] with a user-friendly message on failure.
  Future<void> placeBid({
    required String itemId,
    required String bidderName,
    required int quantity,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw BookingException('Please sign in first.');
    final name = bidderName.trim();
    if (name.length < 2) throw BookingException('Please enter your full name.');
    if (quantity < 1) throw BookingException('Quantity must be at least 1.');

    final itemRef = _items.doc(itemId);
    final tallyRef = _bidders.doc(user.uid);
    await _db.runTransaction((tx) async {
      final settings = AuctionSettings.fromDoc(await tx.get(_settings));
      final now = DateTime.now();
      if (settings.notStarted(now)) {
        throw BookingException('Booking has not started yet.');
      }
      if (!settings.isOpen(now)) throw BookingException('Booking has closed.');

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

      final tally = BidderTally.fromDoc(await tx.get(tallyRef));
      final newItemCount = tally.forItem(item.id) + quantity;
      final newTotal = tally.total + quantity;
      if (settings.maxPerItemPerPerson > 0 &&
          newItemCount > settings.maxPerItemPerPerson) {
        final left = settings.maxPerItemPerPerson - tally.forItem(item.id);
        throw BookingException(left <= 0
            ? 'You have reached the limit of ${settings.maxPerItemPerPerson} '
                'piece(s) for this item.'
            : 'You can book only $left more of this item '
                '(limit ${settings.maxPerItemPerPerson} per person).');
      }
      if (settings.maxTotalPerPerson > 0 &&
          newTotal > settings.maxTotalPerPerson) {
        final left = settings.maxTotalPerPerson - tally.total;
        throw BookingException(left <= 0
            ? 'You have reached the overall limit of '
                '${settings.maxTotalPerPerson} piece(s).'
            : 'You can book only $left more piece(s) in total '
                '(limit ${settings.maxTotalPerPerson} per person).');
      }

      final bidRef = _bids.doc();
      tx.set(bidRef, {
        'itemId': item.id,
        'itemName': item.name,
        'bidderName': name,
        'email': user.email,
        'quantity': quantity,
        'unitPrice': item.price,
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(itemRef, {
        'remaining': item.remaining - quantity,
        'lastBidId': bidRef.id,
      });
      tx.set(tallyRef, {
        'name': name,
        'email': user.email,
        'total': newTotal,
        'items': {...tally.items, item.id: newItemCount},
        'lastBidId': bidRef.id,
      });
    });
  }

  // --------------------------------------------------------------- admin

  Future<void> saveSettings(AuctionSettings s) => _settings.set({
        'title': s.title,
        'startsAt': s.startsAt == null ? null : Timestamp.fromDate(s.startsAt!),
        'endsAt': s.endsAt == null ? null : Timestamp.fromDate(s.endsAt!),
        'maxPerItemPerPerson': s.maxPerItemPerPerson,
        'maxTotalPerPerson': s.maxTotalPerPerson,
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

  /// Cancels a bid: returns the pieces to stock, reduces the bidder's tally
  /// and removes its payment status.
  Future<void> deleteBid(Bid bid) => _db.runTransaction((tx) async {
        final itemRef = _items.doc(bid.itemId);
        final itemSnap = await tx.get(itemRef);
        final tallyRef = bid.uid.isEmpty ? null : _bidders.doc(bid.uid);
        final tallySnap = tallyRef == null ? null : await tx.get(tallyRef);

        if (itemSnap.exists) {
          final item = Item.fromDoc(itemSnap);
          tx.update(itemRef, {
            'remaining': (item.remaining + bid.quantity).clamp(0, item.quantity),
          });
        }
        if (tallySnap != null && tallySnap.exists) {
          final t = BidderTally.fromDoc(tallySnap);
          final left = (t.forItem(bid.itemId) - bid.quantity).clamp(0, 1 << 30);
          tx.update(tallyRef!, {
            'total': (t.total - bid.quantity).clamp(0, 1 << 30),
            'items.${bid.itemId}': left,
          });
        }
        tx.delete(_status.doc(bid.id));
        tx.delete(_bids.doc(bid.id));
      });

  Future<void> setPaid(String bidId, bool paid) => _status.doc(bidId).set({
        'paid': paid,
        'paidAt': paid ? FieldValue.serverTimestamp() : null,
        'updatedBy': _auth.currentUser?.email,
      }, SetOptions(merge: true));

  Future<void> setCollected(String bidId, bool collected) =>
      _status.doc(bidId).set({
        'collected': collected,
        'collectedAt': collected ? FieldValue.serverTimestamp() : null,
        'updatedBy': _auth.currentUser?.email,
      }, SetOptions(merge: true));

  Future<void> setNote(String bidId, String note) => _status.doc(bidId).set({
        'note': note.trim(),
        'updatedBy': _auth.currentUser?.email,
      }, SetOptions(merge: true));
}

class BookingException implements Exception {
  final String message;
  BookingException(this.message);
  @override
  String toString() => message;
}

class AuthMessage implements Exception {
  final String message;
  AuthMessage(this.message);
  @override
  String toString() => message;
}
