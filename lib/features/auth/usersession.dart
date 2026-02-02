import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

@immutable
class AtlasUserProfile {
  final String uid;
  final String email;
  final String firstName;
  final String surname;
  final String displayName;
  final String provider;
  final DateTime? createdAt;

  const AtlasUserProfile({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.surname,
    required this.displayName,
    required this.provider,
    required this.createdAt,
  });

  factory AtlasUserProfile.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? <String, dynamic>{};

    DateTime? createdAt;
    final rawCreatedAt = data['createdAt'];
    if (rawCreatedAt is Timestamp) createdAt = rawCreatedAt.toDate();

    String _s(dynamic v) => (v is String) ? v : '';

    return AtlasUserProfile(
      uid: _s(data['uid']).isNotEmpty ? _s(data['uid']) : doc.id,
      email: _s(data['email']),
      firstName: _s(data['firstName']),
      surname: _s(data['surname']),
      displayName: _s(data['displayName']),
      provider: _s(data['provider']),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'surname': surname,
      'displayName': displayName,
      'provider': provider,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    };
  }

  AtlasUserProfile copyWith({
    String? uid,
    String? email,
    String? firstName,
    String? surname,
    String? displayName,
    String? provider,
    DateTime? createdAt,
  }) {
    return AtlasUserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      surname: surname ?? this.surname,
      displayName: displayName ?? this.displayName,
      provider: provider ?? this.provider,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class UserSession extends ChangeNotifier {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? _firebaseUser;
  AtlasUserProfile? _profile;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  Object? _lastError;

  UserSession({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    _bootstrap();
  }

  /// Current Firebase user (Auth)
  User? get firebaseUser => _firebaseUser;

  /// Current Firestore profile (users/{uid})
  AtlasUserProfile? get profile => _profile;

  /// True if signed in
  bool get isLoggedIn => _firebaseUser != null;

  /// Convenience
  String? get uid => _firebaseUser?.uid;

  /// Last error captured while listening (optional for debugging / UI)
  Object? get lastError => _lastError;

  void _bootstrap() {
    _firebaseUser = _auth.currentUser;
    _bindToAuthChanges();

    if (_firebaseUser != null) {
      _bindToProfile(_firebaseUser!.uid);
    }
  }

  void _bindToAuthChanges() {
    _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen(
          (user) {
        if (user?.uid == _firebaseUser?.uid) {
          // Same user; still notify in case UI depends on isLoggedIn changes.
          _firebaseUser = user;
          notifyListeners();
          return;
        }

        _firebaseUser = user;
        _profile = null;
        _lastError = null;

        _profileSub?.cancel();
        _profileSub = null;

        if (user != null) {
          _bindToProfile(user.uid);
        }

        notifyListeners();
      },
      onError: (e) {
        _lastError = e;
        notifyListeners();
      },
    );
  }

  void _bindToProfile(String uid) {
    _profileSub?.cancel();
    _profileSub = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (doc) {
        if (!doc.exists) {
          // If the doc is missing, keep profile null but still notify.
          _profile = null;
          notifyListeners();
          return;
        }

        _profile = AtlasUserProfile.fromFirestore(doc);
        _lastError = null;
        notifyListeners();
      },
      onError: (e) {
        _lastError = e;
        notifyListeners();
      },
    );
  }

  /// Forces FirebaseAuth to reload the current user (useful after email verification, etc.)
  Future<void> reloadAuthUser() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await user.reload();
    _firebaseUser = _auth.currentUser;
    notifyListeners();
  }

  /// Signs the user out and clears profile state.
  Future<void> signOut() async {
    _lastError = null;

    await _profileSub?.cancel();
    _profileSub = null;

    _profile = null;
    _firebaseUser = null;
    notifyListeners();

    await _auth.signOut();
  }

  /// Optional helper: update basic profile fields in Firestore.
  Future<void> updateProfile({
    String? firstName,
    String? surname,
    String? displayName,
  }) async {
    final u = _auth.currentUser;
    if (u == null) return;

    final updates = <String, dynamic>{};
    if (firstName != null) updates['firstName'] = firstName;
    if (surname != null) updates['surname'] = surname;
    if (displayName != null) updates['displayName'] = displayName;

    if (updates.isEmpty) return;

    await _firestore.collection('users').doc(u.uid).set(
      updates,
      SetOptions(merge: true),
    );

    // Keep Auth display name in sync if provided
    if (displayName != null && displayName.trim().isNotEmpty) {
      await u.updateDisplayName(displayName.trim());
      await reloadAuthUser();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}