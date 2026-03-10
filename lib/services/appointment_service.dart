import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Stream appuntamenti per data range (real-time) ───────────────────
  Stream<List<Appointment>> getAppointments(DateTime start, DateTime end) {
    return _firestore
        .collection('appointments')
        .where('deleted', isEqualTo: false)
        .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('data', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('data')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Appointment.fromFirestore(d)).toList());
  }

  // ── Fetch one-shot per report ───────────────────────────────────────
  Future<List<Appointment>> getAppointmentsOnce(
      DateTime start, DateTime end) async {
    final snap = await _firestore
        .collection('appointments')
        .where('deleted', isEqualTo: false)
        .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('data', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('data')
        .get();
    return snap.docs.map((d) => Appointment.fromFirestore(d)).toList();
  }

  // ── Appuntamenti per singolo utente ────────────────────────────────
  Stream<List<Appointment>> getAppointmentsByUser(
      String userId, DateTime start, DateTime end) {
    return _firestore
        .collection('appointments')
        .where('deleted', isEqualTo: false)
        .where('userId', isEqualTo: userId)
        .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('data', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('data')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Appointment.fromFirestore(d)).toList());
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────
  Future<String> createAppointment(Appointment appointment) async {
    final doc = await _firestore
        .collection('appointments')
        .add(appointment.toFirestore());
    return doc.id;
  }

  Future<void> updateAppointment(String id, Map<String, dynamic> data) async {
    await _firestore.collection('appointments').doc(id).update(data);
  }

  Future<void> deleteAppointment(String id) async {
    await _firestore.collection('appointments').doc(id).update({
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Helper overlap ──────────────────────────────────────────────────
  bool _overlaps(Appointment apt, String oraInizio, String oraFine) {
    return _toMinutes(apt.oraInizio) < _toMinutes(oraFine) &&
        _toMinutes(apt.oraFine) > _toMinutes(oraInizio);
  }

  ({Timestamp dayStart, Timestamp dayEnd}) _dayRange(DateTime data) {
    return (
      dayStart: Timestamp.fromDate(DateTime(data.year, data.month, data.day)),
      dayEnd: Timestamp.fromDate(
          DateTime(data.year, data.month, data.day, 23, 59, 59)),
    );
  }

  // ── Check conflitto STANZA ────────────────────────────────────────────
  Future<Appointment?> checkRoomConflict(
    String roomId,
    DateTime data,
    String oraInizio,
    String oraFine, {
    String? excludeId,
  }) async {
    final r = _dayRange(data);
    final snap = await _firestore
        .collection('appointments')
        .where('deleted', isEqualTo: false)
        .where('roomId', isEqualTo: roomId)
        .where('data', isGreaterThanOrEqualTo: r.dayStart)
        .where('data', isLessThanOrEqualTo: r.dayEnd)
        .get();
    for (final doc in snap.docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      final apt = Appointment.fromFirestore(doc);
      if (_overlaps(apt, oraInizio, oraFine)) return apt;
    }
    return null;
  }

  // ── Check conflitto CLIENTE ───────────────────────────────────────────
  Future<Appointment?> checkClientConflict(
    String clientId,
    DateTime data,
    String oraInizio,
    String oraFine, {
    String? excludeId,
  }) async {
    final r = _dayRange(data);
    final snap = await _firestore
        .collection('appointments')
        .where('deleted', isEqualTo: false)
        .where('clientId', isEqualTo: clientId)
        .where('data', isGreaterThanOrEqualTo: r.dayStart)
        .where('data', isLessThanOrEqualTo: r.dayEnd)
        .get();
    for (final doc in snap.docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      final apt = Appointment.fromFirestore(doc);
      if (_overlaps(apt, oraInizio, oraFine)) return apt;
    }
    return null;
  }

  // ── Check conflitto LAVORATORE (userId o workerIds) ──────────────────
  // Controlla sia il campo userId (responsabile) che workerIds (array).
  // Restituisce il primo appuntamento in conflitto trovato per quel worker.
  Future<Appointment?> checkWorkerConflict(
    String workerId,
    DateTime data,
    String oraInizio,
    String oraFine, {
    String? excludeId,
  }) async {
    final r = _dayRange(data);

    // Query 1: conflitto come userId (responsabile)
    final snapUserId = await _firestore
        .collection('appointments')
        .where('deleted', isEqualTo: false)
        .where('userId', isEqualTo: workerId)
        .where('data', isGreaterThanOrEqualTo: r.dayStart)
        .where('data', isLessThanOrEqualTo: r.dayEnd)
        .get();
    for (final doc in snapUserId.docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      final apt = Appointment.fromFirestore(doc);
      if (_overlaps(apt, oraInizio, oraFine)) return apt;
    }

    // Query 2: conflitto come worker aggiuntivo (workerIds array-contains)
    final snapWorker = await _firestore
        .collection('appointments')
        .where('deleted', isEqualTo: false)
        .where('workerIds', arrayContains: workerId)
        .where('data', isGreaterThanOrEqualTo: r.dayStart)
        .where('data', isLessThanOrEqualTo: r.dayEnd)
        .get();
    for (final doc in snapWorker.docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      final apt = Appointment.fromFirestore(doc);
      if (_overlaps(apt, oraInizio, oraFine)) return apt;
    }

    return null;
  }

  int _toMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
