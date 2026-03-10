import 'dart:async';
import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../services/appointment_service.dart';

/// Provider per gli appuntamenti con cache locale e gestione automatica
/// del listener Firestore. Quando la finestra di date cambia, il vecchio
/// listener viene cancellato e ne viene aperto uno nuovo.
class AppointmentProvider extends ChangeNotifier {
  final AppointmentService _service = AppointmentService();

  List<Appointment> _appointments = [];
  bool _loading = false;
  String? _error;
  StreamSubscription<List<Appointment>>? _sub;

  List<Appointment> get appointments => _appointments;
  bool get loading => _loading;
  String? get error => _error;

  DateTime? _currentStart;
  DateTime? _currentEnd;

  /// Ascolta gli appuntamenti per un range di date.
  /// Se il range è lo stesso già attivo, non apre un nuovo listener.
  void listenRange(DateTime start, DateTime end) {
    if (_currentStart == start && _currentEnd == end) return;
    _currentStart = start;
    _currentEnd = end;
    _sub?.cancel();
    _loading = true;
    _error = null;
    notifyListeners();

    _sub = _service.getAppointments(start, end).listen(
      (list) {
        _appointments = list;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _loading = false;
        notifyListeners();
      },
    );
  }

  /// Aggiorna la cache locale ottimisticamente senza aspettare Firestore.
  void updateOptimistic(String id, Map<String, dynamic> data) {
    _appointments = _appointments.map((a) {
      if (a.id != id) return a;
      return Appointment(
        id: a.id,
        titolo: data['titolo'] ?? a.titolo,
        data: a.data,
        oraInizio: data['oraInizio'] ?? a.oraInizio,
        oraFine: data['oraFine'] ?? a.oraFine,
        oreTotali: (data['oreTotali'] ?? a.oreTotali).toDouble(),
        tariffa: (data['tariffa'] ?? a.tariffa).toDouble(),
        totale: (data['totale'] ?? a.totale).toDouble(),
        userId: a.userId,
        createdBy: a.createdBy,
        clientId: a.clientId,
        roomId: a.roomId,
        workerIds: a.workerIds,
        note: data['note'] ?? a.note,
        isSocio: a.isSocio,
        fatturato: data['fatturato'] ?? a.fatturato,
        pagato: data['pagato'] ?? a.pagato,
        deleted: a.deleted,
        createdAt: a.createdAt,
      );
    }).toList();
    notifyListeners();
  }

  /// Rimuove localmente un appuntamento cancellato (soft-delete ottimistico).
  void removeOptimistic(String id) {
    _appointments = _appointments.where((a) => a.id != id).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
