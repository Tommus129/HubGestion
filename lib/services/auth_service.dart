import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UfficioUser? _ufficioUser;

  UfficioUser? get currentUser => _ufficioUser;
  User? get firebaseUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;

  AuthService() {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _loadUserData(user.uid);
      } else {
        _ufficioUser = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _ufficioUser = UfficioUser.fromFirestore(doc.data()!, uid);
      } else {
        _ufficioUser = UfficioUser(
          uid: uid,
          email: _auth.currentUser!.email!,
          displayName: _auth.currentUser!.displayName ?? '',
          role: 'employee',
        );
        await _firestore.collection('users').doc(uid).set(_ufficioUser!.toFirestore());
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    }
    notifyListeners();
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found': return 'Nessun account trovato.';
        case 'wrong-password': return 'Password errata.';
        case 'invalid-email': return 'Email non valida.';
        default: return 'Errore: ${e.message}';
      }
    }
  }

  Future<String?> register(String email, String password, String displayName) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
      await result.user?.updateDisplayName(displayName);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use': return 'Email già registrata.';
        case 'weak-password': return 'Password troppo debole (min. 6 caratteri).';
        default: return 'Errore: ${e.message}';
      }
    }
  }

  Future<void> signOut() async => await _auth.signOut();
}
