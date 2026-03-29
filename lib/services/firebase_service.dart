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
}
