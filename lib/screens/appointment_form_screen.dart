import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ import mancante
import 'package:provider/provider.dart';
import '../models/appointment.dart';
import '../models/room.dart';
import '../models/client.dart';
import '../services/appointment_service.dart';
import '../services/room_service.dart';
import '../services/client_service.dart';
import '../services/auth_service.dart';
import '../widgets/time_picker_24h.dart';

class AppointmentFormScreen extends StatefulWidget {
  final DateTime selectedDay;
  final Appointment? appointment;
  AppointmentFormScreen({required this.selectedDay, this.appointment});

  @override
  _AppointmentFormScreenState createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titoloController = TextEditingController();

  // ✅ PRIMA era hardcoded a '50' [cite:52]
  final _tariffaController = TextEditingController();

  final AppointmentService _aptService = AppointmentService();
  final RoomService _roomService = RoomService();
  final ClientService _clientService = ClientService();

  // ✅ Data modificabile dall'utente
  late DateTime _selectedDay;

  TimeOfDay _oraInizio = TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _oraFine = TimeOfDay(hour: 10, minute: 0);
  int _durataMinuti = 60;
  Room? _selectedRoom;
  Client? _selectedClient;
  bool _loading = false;
  bool _fatturato = false;
  bool _pagato = false;

  List<Room> _rooms = [];
  List<Client> _clients = [];
  bool get isEditing => widget.appointment != null;

  @override
  void initState() {
    super.initState();

    _selectedDay = widget.appointment != null
        ? widget.appointment!.data
        : widget.selectedDay;

    // ✅ Tariffa proposta dal profilo utente (se presente), fallback 50 [cite:56][cite:57]
    final auth = Provider.of<AuthService>(context, listen: false);
    final tariffaDefault = auth.currentUser?.tariffa ?? 50.0;
    _tariffaController.text = tariffaDefault.toStringAsFixed(0);

    _loadData();
    if (isEditing) _prefillForm(); // in edit sovrascrive con la tariffa dell'appuntamento [cite:52]
  }

  void _prefillForm() {
    final apt = widget.appointment!;
    _titoloController.text = apt.titolo;
    _tariffaController.text = apt.tariffa.toString();
    _fatturato = apt.fatturato;
    _pagato = apt.pagato;
    final s = apt.oraInizio.split(':');
    final e = apt.oraFine.split(':');
    _oraInizio = TimeOfDay(hour: int.parse(s[0]), minute: int.parse(s[1]));
    _oraFine = TimeOfDay(hour: int.parse(e[0]), minute: int.parse(e[1]));
    _durataMinuti = (_oraFine.hour * 60 + _oraFine.minute) -
        (_oraInizio.hour * 60 + _oraInizio.minute);
  }

  void _loadData() {
    _roomService.getRooms().listen((rooms) => setState(() {
          _rooms = rooms;
          if (isEditing && _selectedRoom == null) {
            final m = rooms.where((r) => r.id == widget.appointment!.roomId);
            if (m.isNotEmpty) _selectedRoom = m.first;
          }
        }));
    _clientService.getClients().listen((clients) => setState(() {
          _clients = clients;
          if (isEditing && _selectedClient == null) {
            final m =
                clients.where((c) => c.id == widget.appointment!.clientId);
            if (m.isNotEmpty) _selectedClient = m.first;
          }
        }));
  }

  // ✅ DatePicker per cambiare giorno
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDay = picked);
  }

  void _onInizioChanged(TimeOfDay t) {
    setState(() {
      _oraInizio = t;
      final totalMin = t.hour * 60 + t.minute + _durataMinuti;
      _oraFine = TimeOfDay(hour: (totalMin ~/ 60) % 24, minute: totalMin % 60);
    });
  }

  void _onFineChanged(TimeOfDay t) {
    setState(() {
      _oraFine = t;
      final diff = (t.hour * 60 + t.minute) -
          (_oraInizio.hour * 60 + _oraInizio.minute);
      if (diff > 0) _durataMinuti = diff;
    });
  }

  String _timeStr(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _durataLabel() {
    final h = _durataMinuti ~/ 60;
    final m = _durataMinuti % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h ${m}min';
  }

  double get _oreTotali => _durataMinuti / 60.0;
  double get _tariffa => double.tryParse(_tariffaController.text) ?? 0;
  double get _totale => _oreTotali * _tariffa;

  // ✅ Dialog conflitto generico riutilizzabile
  Future<bool> _showConflictDialog({
    required String titolo,
    required String messaggio,
    required Color colore,
  }) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Icon(Icons.warning_amber, color: colore),
          SizedBox(width: 8),
          Text(titolo),
        ]),
        content: Text(messaggio),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: colore),
            child: Text('Continua'),
          ),
        ],
      ),
    );
    return go == true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoom == null) {
      _err('Seleziona una stanza');
      return;
    }
    if (_selectedClient == null) {
      _err('Seleziona un cliente');
      return;
    }
    setState(() => _loading = true);

    final auth = Provider.of<AuthService>(context, listen: false);
    final inicio = _timeStr(_oraInizio);
    final fine = _timeStr(_oraFine);

    // ✅ Data normalizzata senza ore/minuti per il confronto Firestore
    final dataNorm =
        DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);

    // ── Controllo conflitto STANZA ──────────────────────────────
    final roomConflict = await _aptService.checkRoomConflict(
      _selectedRoom!.id!,
      dataNorm,
      inicio,
      fine,
      excludeId: widget.appointment?.id,
    );
    if (roomConflict != null && mounted) {
      final go = await _showConflictDialog(
        titolo: 'Conflitto Stanza',
        messaggio: '"${_selectedRoom!.name}" è già occupata\n'
            'da "${roomConflict.titolo}"\n'
            '(${roomConflict.oraInizio} – ${roomConflict.oraFine})\n\n'
            'Vuoi continuare comunque?',
        colore: Colors.orange,
      );
      if (!go) {
        setState(() => _loading = false);
        return;
      }
    }

    // ── Controllo conflitto CLIENTE ✅ NUOVO ────────────────────
    final clientConflict = await _aptService.checkClientConflict(
      _selectedClient!.id!,
      dataNorm,
      inicio,
      fine,
      excludeId: widget.appointment?.id,
    );
    if (clientConflict != null && mounted) {
      final go = await _showConflictDialog(
        titolo: 'Conflitto Cliente',
        messaggio: '"${_selectedClient!.fullName}" ha già un appuntamento\n'
            'in questo orario: "${clientConflict.titolo}"\n'
            '(${clientConflict.oraInizio} – ${clientConflict.oraFine})\n\n'
            'Vuoi continuare comunque?',
        colore: Colors.red,
      );
      if (!go) {
        setState(() => _loading = false);
        return;
      }
    }

    try {
      if (isEditing) {
        await _aptService.updateAppointment(widget.appointment!.id!, {
          'titolo': _titoloController.text,
          'data': Timestamp.fromDate(dataNorm), // ✅ usa Timestamp
          'oraInizio': inicio,
          'oraFine': fine,
          'oreTotali': _oreTotali,
          'tariffa': _tariffa,
          'totale': _totale,
          'roomId': _selectedRoom!.id,
          'clientId': _selectedClient!.id,
          'fatturato': _fatturato,
          'pagato': _pagato,
        });
      } else {
        await _aptService.createAppointment(Appointment(
          titolo: _titoloController.text,
          data: dataNorm,
          oraInizio: inicio,
          oraFine: fine,
          oreTotali: _oreTotali,
          tariffa: _tariffa,
          totale: _totale,
          userId: auth.firebaseUser!.uid,
          createdBy: auth.firebaseUser!.uid,
          clientId: _selectedClient!.id!,
          roomId: _selectedRoom!.id!,
        ));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _err('Errore: $e');
      setState(() => _loading = false);
    }
  }

  void _err(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifica Appuntamento' : 'Nuovo Appuntamento'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TITOLO
              TextFormField(
                controller: _titoloController,
                decoration: InputDecoration(
                  labelText: 'Titolo *',
                  prefixIcon: Icon(Icons.title),
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (v) => v!.isEmpty ? 'Campo obbligatorio' : null,
              ),
              SizedBox(height: 16),

              // ✅ DATA — cliccabile con DatePicker
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.05),
                    border: Border.all(color: primary.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today, color: primary, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_selectedDay.day.toString().padLeft(2, '0')}/'
                        '${_selectedDay.month.toString().padLeft(2, '0')}/'
                        '${_selectedDay.year}',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.edit_calendar, color: primary, size: 18),
                  ]),
                ),
              ),
              SizedBox(height: 20),

              // ORARI
              Text('Orario',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                      fontSize: 13,
                      letterSpacing: 0.5)),
              SizedBox(height: 10),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TimePicker24h(
                      label: 'Inizio',
                      initialTime: _oraInizio,
                      onChanged: _onInizioChanged,
                    ),
                  ),
                  SizedBox(width: 12),
                  Column(children: [
                    Text('Durata',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500)),
                    SizedBox(height: 4),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: primary.withOpacity(0.2)),
                      ),
                      child: Column(children: [
                        InkWell(
                          onTap: () => setState(() {
                            _durataMinuti = (_durataMinuti + 15).clamp(15, 480);
                            final t = _oraInizio.hour * 60 +
                                _oraInizio.minute +
                                _durataMinuti;
                            _oraFine = TimeOfDay(
                                hour: (t ~/ 60) % 24, minute: t % 60);
                          }),
                          child: Icon(Icons.add_circle_outline,
                              color: primary, size: 22),
                        ),
                        SizedBox(height: 4),
                        Text(_durataLabel(),
                            style: TextStyle(
                                color: primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        SizedBox(height: 4),
                        InkWell(
                          onTap: () => setState(() {
                            _durataMinuti = (_durataMinuti - 15).clamp(15, 480);
                            final t = _oraInizio.hour * 60 +
                                _oraInizio.minute +
                                _durataMinuti;
                            _oraFine = TimeOfDay(
                                hour: (t ~/ 60) % 24, minute: t % 60);
                          }),
                          child: Icon(Icons.remove_circle_outline,
                              color: primary, size: 22),
                        ),
                      ]),
                    ),
                  ]),
                  SizedBox(width: 12),
                  Expanded(
                    child: TimePicker24h(
                      label: 'Fine',
                      initialTime: _oraFine,
                      onChanged: _onFineChanged,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // STANZA
              DropdownButtonFormField<Room>(
                value: _selectedRoom,
                decoration: InputDecoration(
                  labelText: 'Stanza *',
                  prefixIcon: Icon(Icons.meeting_room),
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: _rooms.map((r) {
                  final c = Color(
                      int.parse('FF${r.color.replaceAll("#", "")}', radix: 16));
                  return DropdownMenuItem(
                    value: r,
                    child: Row(children: [
                      Container(
                          width: 12,
                          height: 12,
                          decoration:
                              BoxDecoration(color: c, shape: BoxShape.circle)),
                      SizedBox(width: 8),
                      Text(r.name),
                    ]),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedRoom = v),
                hint: Text('Seleziona stanza'),
              ),
              SizedBox(height: 16),

              // CLIENTE
              DropdownButtonFormField<Client>(
                value: _selectedClient,
                decoration: InputDecoration(
                  labelText: 'Cliente *',
                  prefixIcon: Icon(Icons.person),
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: _clients
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.fullName)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedClient = v),
                hint: Text('Seleziona cliente'),
              ),
              SizedBox(height: 16),

              // TARIFFA
              TextFormField(
                controller: _tariffaController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Tariffa €/ora',
                  prefixIcon: Icon(Icons.euro),
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              SizedBox(height: 12),

              // TOTALE
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primary.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        '${_timeStr(_oraInizio)} → ${_timeStr(_oraFine)}  •  ${_durataLabel()}',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      SizedBox(height: 2),
                      Text('Totale stimato',
                          style: TextStyle(color: primary, fontSize: 13)),
                    ]),
                    Text('€ ${_totale.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 22)),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // FATTURATO / PAGATO (solo modifica)
              if (isEditing) ...[
                Row(children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: Text('Fatturato', style: TextStyle(fontSize: 13)),
                      value: _fatturato,
                      activeColor: Colors.orange,
                      dense: true,
                      onChanged: (v) => setState(() => _fatturato = v!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: CheckboxListTile(
                      title: Text('Pagato', style: TextStyle(fontSize: 13)),
                      value: _pagato,
                      activeColor: Colors.green,
                      dense: true,
                      onChanged: (v) => setState(() => _pagato = v!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ),
                ]),
                SizedBox(height: 16),
              ],

              // SALVA
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _save,
                  icon: _loading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Icon(isEditing ? Icons.save : Icons.add),
                  label: Text(
                    isEditing ? 'Salva Modifiche' : 'Crea Appuntamento',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
