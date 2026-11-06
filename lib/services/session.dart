import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';

/// Who is using the app right now.
class Session {
  final User? user;
  final bool isAdmin;
  final bool loading;

  const Session({this.user, this.isAdmin = false, this.loading = false});

  bool get signedIn => user != null;
  bool get emailVerified => user?.emailVerified ?? false;
  bool get allowedDomain => isAllowedEmail(user?.email);

  /// Verified @ijm.org staff, or an admin (admins are always allowed).
  bool get canUseSite =>
      isAdmin || (signedIn && emailVerified && allowedDomain);
}

/// Keeps the current [Session] up to date (auth state + admin flag).
class SessionController extends ChangeNotifier {
  SessionController._() {
    _authSub = FirebaseAuth.instance.userChanges().listen(_onUser);
  }
  static final instance = SessionController._();

  Session _value = const Session(loading: true);
  Session get value => _value;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot>? _adminSub;
  String? _adminUid;

  void _set(Session s) {
    _value = s;
    notifyListeners();
  }

  void _onUser(User? user) {
    if (user == null) {
      _adminSub?.cancel();
      _adminSub = null;
      _adminUid = null;
      _set(const Session());
      return;
    }
    if (_adminUid == user.uid && _adminSub != null) {
      // Same user, e.g. after reload(): keep the admin flag.
      _set(Session(user: user, isAdmin: _value.isAdmin));
      return;
    }
    _adminSub?.cancel();
    _adminUid = user.uid;
    _set(Session(user: user, loading: true));
    _adminSub = FirebaseFirestore.instance
        .collection('admins')
        .doc(user.uid)
        .snapshots()
        .listen(
          (d) => _set(
            Session(user: FirebaseAuth.instance.currentUser, isAdmin: d.exists),
          ),
          onError: (_) =>
              _set(Session(user: FirebaseAuth.instance.currentUser)),
        );
  }

  /// Re-checks the user (e.g. after they clicked the verification link) and
  /// refreshes the ID token so the database sees `email_verified = true`.
  Future<void> refresh() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    await u.reload();
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
    final fresh = FirebaseAuth.instance.currentUser;
    _set(Session(user: fresh, isAdmin: _value.isAdmin));
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _adminSub?.cancel();
    super.dispose();
  }
}
