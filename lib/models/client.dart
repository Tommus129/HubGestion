import 'package:cloud_firestore/cloud_firestore.dart';

class Client {
  final String? id;
  final String nome;
  final String cognome;
  final String? email;
  final String? telefono;
  final String? note;
  final String? genitori;
  final String? codiceFiscale;
  final String? indirizzo;
  final bool archived;

  Client({
    this.id,
    required this.nome,
    required this.cognome,
    this.email,
    this.telefono,
    this.note,
    this.genitori,
    this.codiceFiscale,
    this.indirizzo,
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
      genitori: data['genitori'],
      codiceFiscale: data['codiceFiscale'],
      indirizzo: data['indirizzo'],
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
      'genitori': genitori ?? '',
      'codiceFiscale': codiceFiscale ?? '',
      'indirizzo': indirizzo ?? '',
      'archived': archived,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
