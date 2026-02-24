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
  bool get isLoggedIn => _ufficioUser != null;

  AuthService() {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        // Ascolta in REALTIME il documento utente
        _firestore
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((doc) {
          if (doc.exists) {
            final data = doc.data()!;
            debugPrint('=== USER DOC AGGIORNATO ===');
            debugPrint('UID: ${doc.id}');
            debugPrint('Email: ${data['email']}');
            debugPrint('Role: ${data['role']}');
            debugPrint('==========================');
            _ufficioUser = UfficioUser.fromFirestore(data, doc.id);
            notifyListeners();
          } else {
            debugPrint('=== DOCUMENTO NON ESISTE, CREO NUOVO ===');
            _createNewUser(user);
          }
        });
      } else {
        _ufficioUser = null;
        notifyListeners();
      }
    });
  }

  Future<void> _createNewUser(User user) async {
    _ufficioUser = UfficioUser(
      uid: user.uid,
      email: user.email!,
      displayName: user.displayName ?? '',
      role: 'employee',
    );
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(_ufficioUser!.toFirestore());
    notifyListeners();
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'Nessun account trovato.';
        case 'wrong-password':
          return 'Password errata.';
        case 'invalid-email':
          return 'Email non valida.';
        case 'invalid-credential':
          return 'Credenziali non valide.';
        default:
          return 'Errore: ${e.message}';
      }
    }
  }

  Future<String?> register(
      String email, String password, String displayName) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      await result.user?.updateDisplayName(displayName);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Email già registrata.';
        case 'weak-password':
          return 'Password troppo debole.';
        default:
          return 'Errore: ${e.message}';
      }
    }
  }

  // ── LOGOUT AFFIDABILE ────────────────────────────────────────────────────
  Future<void> signOut() async {
    // Reset immediato — garantisce il redirect alla LoginScreen
    // anche se lo stream authStateChanges è lento su web
    _ufficioUser = null;
    notifyListeners();
    await _auth.signOut();
  }
}
