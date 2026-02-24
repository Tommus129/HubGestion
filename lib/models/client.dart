import 'package:cloud_firestore/cloud_firestore.dart';

class Client {
  final String? id;
  final String nome;
  final String cognome;
  final String? email;
  final String? telefono;
  final String? note;
  final bool archived;

  Client({
    this.id,
    required this.nome,
    required this.cognome,
    this.email,
    this.telefono,
    this.note,
    this.archived = false,
  });

  String get fullName => '$nome $cognome';

  factory Client.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Client(
      id: doc.id,
      nome: data['nome'] ?? '',
      cognome: data['cognome'] ?? '',
      email: data['email'],
      telefono: data['telefono'],
      note: data['note'],
      archived: data['archived'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nome': nome,
      'cognome': cognome,
      'email': email ?? '',
      'telefono': telefono ?? '',
      'note': note ?? '',
      'archived': archived,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
