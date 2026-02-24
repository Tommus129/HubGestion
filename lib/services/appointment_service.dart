import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream appuntamenti per data range
  Stream<List<Appointment>> getAppointments(DateTime start, DateTime end) {
    return _firestore
        .collection('appointments')
        .where('deleted', isEqualTo: false)
        .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('data', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots()
        .map((snap) => snap.docs.map((d) => Appointment.fromFirestore(d)).toList());
  }

  // Crea appuntamento
  Future<String> createAppointment(Appointment appointment) async {
    final doc = await _firestore.collection('appointments').add(appointment.toFirestore());
    return doc.id;
  }

  // Aggiorna appuntamento
  Future<void> updateAppointment(String id, Map<String, dynamic> data) async {
    await _firestore.collection('appointments').doc(id).update(data);
  }

  // Soft-delete
  Future<void> deleteAppointment(String id) async {
    await _firestore.collection('appointments').doc(id).update({
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Check conflitti STANZA ──────────────────────────────────────
  Future<Appointment?> checkRoomConflict(
    String roomId,
    DateTime data,
    String oraInizio,
    String oraFine, {
    String? excludeId,
  }) async {
    final snap = await _firestore
        .collection('appointments')
        .where('deleted', isEqualTo: false)
        .where('roomId', isEqualTo: roomId)
        .where('data', isEqualTo: Timestamp.fromDate(
            DateTime(data.year, data.month, data.day)))
        .get();

    for (final doc in snap.docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      final apt = Appointment.fromFirestore(doc);
      if (_timeOverlap(oraInizio, oraFine, apt.oraInizio, apt.oraFine)) {
        return apt;
      }
    }
    return null;
  }

  // ── Check conflitti CLIENTE ✅ NUOVO ────────────────────────────
  Future<Appointment?> checkClientConflict(
    String clientId,
    DateTime data,
    String oraInizio,
    String oraFine, {
    String? excludeId,
  }) async {
    final snap = await _firestore
        .collection('appointments')
        .where('deleted', isEqualTo: false)
        .where('clientId', isEqualTo: clientId)
        .where('data', isEqualTo: Timestamp.fromDate(
            DateTime(data.year, data.month, data.day)))
        .get();

    for (final doc in snap.docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      final apt = Appointment.fromFirestore(doc);
      if (_timeOverlap(oraInizio, oraFine, apt.oraInizio, apt.oraFine)) {
        return apt;
      }
    }
    return null;
  }

  bool _timeOverlap(String start1, String end1, String start2, String end2) {
    final s1 = _toMinutes(start1);
    final e1 = _toMinutes(end1);
    final s2 = _toMinutes(start2);
    final e2 = _toMinutes(end2);
    return s1 < e2 && e1 > s2;
  }

  int _toMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
