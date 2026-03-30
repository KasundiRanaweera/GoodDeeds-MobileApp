import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Set<String> _allowedRoles = {'Volunteer', 'Organizer'};

  String _normalizeRole(String role) {
    final normalized = role.trim().toLowerCase();
    if (normalized == 'volunteer') return 'Volunteer';
    if (normalized == 'organizer') return 'Organizer';
    throw Exception('Role must be Volunteer or Organizer.');
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  }) async {
    try {
      final normalizedRole = _normalizeRole(role);
      if (!_allowedRoles.contains(normalizedRole)) {
        throw Exception('Role must be Volunteer or Organizer.');
      }

      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Update display name
      await userCredential.user?.updateDisplayName(name);

      // Save additional user data to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'phone': phone,
        'role': normalizedRole,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Keep editable profile fields in a separate collection.
      await _firestore
          .collection('user_profiles')
          .doc(userCredential.user!.uid)
          .set({
            'name': name,
            'phone': phone,
            'photoUrl': '',
            'bio': '',
            'address': '',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      return userCredential;
    } catch (e, st) {
      // Log the full error to console for debugging.
      // The UI will show the user-friendly message.
      debugPrint('FirebaseService.signUp error: $e\n$st');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  // Get editable user profile data from dedicated profile collection.
  Future<Map<String, dynamic>?> getUserProfileData(String uid) async {
    try {
      final doc = await _firestore.collection('user_profiles').doc(uid).get();
      return doc.data();
    } catch (e) {
      throw Exception('Failed to get user profile data: $e');
    }
  }

  // Merge auth/base user data with profile collection (profile values override).
  Future<Map<String, dynamic>> getMergedUserData(String uid) async {
    final base = await getUserData(uid) ?? <String, dynamic>{};
    final profile = await getUserProfileData(uid) ?? <String, dynamic>{};
    return {...base, ...profile};
  }

  // Live stream of base user document data.
  Stream<Map<String, dynamic>> streamUserData(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data() ?? <String, dynamic>{});
  }

  // Update role for the currently signed-in user.
  Future<void> updateCurrentUserRole(String role) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No signed-in user.');
    }

    final normalizedRole = _normalizeRole(role);
    await _firestore.collection('users').doc(user.uid).set({
      'role': normalizedRole,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Stream organizer-created events for volunteer discovery.
  Stream<List<Map<String, dynamic>>> streamOrganizerEvents() {
    return _firestore.collection('events').snapshots().map((snapshot) {
      final events = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      events.sort((a, b) {
        final aTime = (a['createdAt'] as Timestamp?)?.toDate();
        final bTime = (b['createdAt'] as Timestamp?)?.toDate();
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return events;
    });
  }

  // Stream events joined by the current user.
  Stream<List<Map<String, dynamic>>> streamMyJoinedEvents() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(const <Map<String, dynamic>>[]);
    }

    return _firestore
        .collection('events')
        .where('participantIds', arrayContains: user.uid)
        .snapshots()
        .map((snapshot) {
          final events = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();

          DateTime? toDate(dynamic value) {
            if (value is Timestamp) return value.toDate();
            if (value is DateTime) return value;
            if (value is String) return DateTime.tryParse(value);
            return null;
          }

          events.sort((a, b) {
            final aDate = toDate(a['eventDate'] ?? a['date'] ?? a['startDate']);
            final bDate = toDate(b['eventDate'] ?? b['date'] ?? b['startDate']);
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });

          return events;
        });
  }

  // Join an event as the current volunteer.
  Future<void> joinEvent({required String eventId}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please login to join events.');
    }

    final eventRef = _firestore.collection('events').doc(eventId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(eventRef);
      if (!snapshot.exists) {
        throw Exception('Event not found.');
      }

      final data = snapshot.data() ?? <String, dynamic>{};
      final participantIds = List<String>.from(
        (data['participantIds'] as List<dynamic>? ?? const []).map(
          (e) => e.toString(),
        ),
      );

      if (!participantIds.contains(user.uid)) {
        participantIds.add(user.uid);
      }

      transaction.update(eventRef, {
        'participantIds': participantIds,
        'participantsCount': participantIds.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Leave a joined event for the current volunteer.
  Future<void> leaveEvent({required String eventId}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please login to manage events.');
    }

    final eventRef = _firestore.collection('events').doc(eventId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(eventRef);
      if (!snapshot.exists) {
        throw Exception('Event not found.');
      }

      final data = snapshot.data() ?? <String, dynamic>{};
      final participantIds = List<String>.from(
        (data['participantIds'] as List<dynamic>? ?? const []).map(
          (e) => e.toString(),
        ),
      );

      participantIds.removeWhere((id) => id == user.uid);

      transaction.update(eventRef, {
        'participantIds': participantIds,
        'participantsCount': participantIds.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
