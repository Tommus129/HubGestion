import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  final String? id;
  final String titolo;
  final DateTime data;
  final String oraInizio;
  final String oraFine;
  final double oreTotali;
  final double tariffa;
  final double totale;
  final String userId;
  final String createdBy;
  final String clientId;
  final String roomId;
  final bool fatturato;
  final bool pagato;
  final bool deleted;
  final DateTime? createdAt;

  Appointment({
    this.id,
    required this.titolo,
    required this.data,
    required this.oraInizio,
    required this.oraFine,
    required this.oreTotali,
    required this.tariffa,
    required this.totale,
    required this.userId,
    required this.createdBy,
    required this.clientId,
    required this.roomId,
    this.fatturato = false,
    this.pagato = false,
    this.deleted = false,
    this.createdAt,
  });

  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Appointment(
      id: doc.id,
      titolo: data['titolo'] ?? '',
      data: (data['data'] as Timestamp).toDate(),
      oraInizio: data['oraInizio'] ?? '',
      oraFine: data['oraFine'] ?? '',
      oreTotali: (data['oreTotali'] ?? 0).toDouble(),
      tariffa: (data['tariffa'] ?? 0).toDouble(),
      totale: (data['totale'] ?? 0).toDouble(),
      userId: data['userId'] ?? '',
      createdBy: data['createdBy'] ?? '',
      clientId: data['clientId'] ?? '',
      roomId: data['roomId'] ?? '',
      fatturato: data['fatturato'] ?? false,
      pagato: data['pagato'] ?? false,
      deleted: data['deleted'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'titolo': titolo,
      'data': Timestamp.fromDate(data),
      'oraInizio': oraInizio,
      'oraFine': oraFine,
      'oreTotali': oreTotali,
      'tariffa': tariffa,
      'totale': totale,
      'userId': userId,
      'createdBy': createdBy,
      'clientId': clientId,
      'roomId': roomId,
      'fatturato': fatturato,
      'pagato': pagato,
      'deleted': deleted,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
