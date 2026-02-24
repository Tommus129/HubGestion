import 'package:cloud_firestore/cloud_firestore.dart';

class UfficioUser {
  final String uid;
  final String email;
  final String? displayName;
  final String role;
  final String? personaColor;
  final double tariffa;

  UfficioUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.role = 'employee',
    this.personaColor,
    this.tariffa = 50.0,
  });

  factory UfficioUser.fromFirestore(Map<String, dynamic> data, String uid) {
    return UfficioUser(
      uid: uid,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      role: data['role'] ?? 'employee',
      personaColor: data['personaColor'],
      tariffa: (data['tariffa'] as num?)?.toDouble() ?? 50.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName ?? '',
      'role': role,
      'personaColor': personaColor ?? '#4ECDC4',
      'tariffa': tariffa,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  bool get isSuperAdmin => role == 'superadmin';
  bool get isPresidente => role == 'presidente';
  bool get isEmployee => role == 'employee';
  bool get isAdmin => isSuperAdmin || isPresidente;
}
