import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment.dart';

/// Massimo range di giorni consentito per una singola query.
/// Protegge da query su periodi troppo lunghi (es. report annuali).
const int kMaxQueryRangeDays = 31;

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Stream appuntamenti per data range (real-time) ───────────────────
  // Il range è limitato a [kMaxQueryRangeDays] per sicurezza.
  Stream<List<Appointment>> getAppointments(DateTime start, DateTime end) {
    assert(
      end.difference(start).inDays <= kMaxQueryRangeDays,
      'Range troppo ampio: usa Cloud Functions per report su periodi lunghi.',
    );
    return _firestore
        .collection('appointments')
        .where('deleted', isEqualTo: false)
        .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('data', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('data')
        .orderBy('oraInizio')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Appointment.fromFirestore(d)).toList());
  }

  // ── Fetch one-shot per report (no real-time listener) ─────────────────
  // Usa .get() invece di .snapshots() per evitare listener aperti sui report.
  Future<List<Appointment>> getAppointmentsOnce(
      DateTime start, DateTime end) async {
    final snap = await _firestore
        .collection('appointments')
        .where('deleted', isEqualTo: false)
        .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('data', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('data')
        .orderBy('oraInizio')
        .get();
    return snap.docs.map((d) => Appointment.fromFirestore(d)).toList();
  }

  // ── Appuntamenti per singolo utente (scheda operatore) ────────────────
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

  // ── Crea appuntamento ─────────────────────────────────────────────────
  Future<String> createAppointment(Appointment appointment) async {
    final doc = await _firestore
        .collection('appointments')
        .add(appointment.toFirestore());
    return doc.id;
  }

  // ── Aggiorna appuntamento ────────────────────────────────────────────
  Future<void> updateAppointment(String id, Map<String, dynamic> data) async {
    await _firestore.collection('appointments').doc(id).update(data);
  }

  // ── Soft-delete ────────────────────────────────────────────────────────
  Future<void> deleteAppointment(String id) async {
    await _firestore.collection('appointments').doc(id).update({
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Check conflitti STANZA ────────────────────────────────────────────
  // Filtra direttamente su Firestore usando l'indice composito
  // [deleted + roomId + data + oraInizio] per minimizzare documenti scaricati.
  Future<Appointment?> checkRoomConflict(
    String roomId,
    DateTime data,
    String oraInizio,
    String oraFine, {
    String? excludeId,
  }) async {
    final dayStart =
        Timestamp.fromDate(DateTime(data.year, data.month, data.day));
    final dayEnd = Timestamp.fromDate(
        DateTime(data.year, data.month, data.day, 23, 59, 59));

    // Sfrutta l'indice: deleted + roomId + data
    // Poi filtra oraInizio < oraFine richiesta (overlap parziale)
    final snap = await _firestore
        .collection('appointments')
        .where('deleted', isEqualTo: false)
        .where('roomId', isEqualTo: roomId)
        .where('data', isGreaterThanOrEqualTo: dayStart)
        .where('data', isLessThanOrEqualTo: dayEnd)
        .where('oraInizio', isLessThan: oraFine) // inizia prima che finisca il nuovo
        .get();

    for (final doc in snap.docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      final apt = Appointment.fromFirestore(doc);
      // Verifica che finisca dopo l'inizio del nuovo (overlap completo)
      if (_toMinutes(apt.oraFine) > _toMinutes(oraInizio)) {
        return apt;
      }
    }
    return null;
  }

  // ── Check conflitti CLIENTE ───────────────────────────────────────────
  Future<Appointment?> checkClientConflict(
    String clientId,
    DateTime data,
    String oraInizio,
    String oraFine, {
    String? excludeId,
  }) async {
    final dayStart =
        Timestamp.fromDate(DateTime(data.year, data.month, data.day));
    final dayEnd = Timestamp.fromDate(
        DateTime(data.year, data.month, data.day, 23, 59, 59));

    final snap = await _firestore
        .collection('appointments')
        .where('deleted', isEqualTo: false)
        .where('clientId', isEqualTo: clientId)
        .where('data', isGreaterThanOrEqualTo: dayStart)
        .where('data', isLessThanOrEqualTo: dayEnd)
        .where('oraInizio', isLessThan: oraFine)
        .get();

    for (final doc in snap.docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      final apt = Appointment.fromFirestore(doc);
      if (_toMinutes(apt.oraFine) > _toMinutes(oraInizio)) {
        return apt;
      }
    }
    return null;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  int _toMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
