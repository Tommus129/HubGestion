import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/appointment.dart';
import '../models/room.dart';
import '../models/client.dart';
import '../models/user.dart';
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
  final _noteController = TextEditingController();
  final _tariffaController = TextEditingController();

  final AppointmentService _aptService = AppointmentService();
  final RoomService _roomService = RoomService();
  final ClientService _clientService = ClientService();

  late DateTime _selectedDay;

  TimeOfDay _oraInizio = TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _oraFine = TimeOfDay(hour: 10, minute: 0);
  int _durataMinuti = 60;
  Room? _selectedRoom;
  Client? _selectedClient;
  bool _loading = false;
  bool _fatturato = false;
  bool _pagato = false;
  bool _isSocio = true;

  // Multi-lavoratore
  List<UfficioUser> _allUsers = [];
  List<String> _selectedWorkerIds = [];

  List<Room> _rooms = [];
  List<Client> _clients = [];
  bool get isEditing => widget.appointment != null;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.appointment != null
        ? widget.appointment!.data
        : widget.selectedDay;
    final auth = Provider.of<AuthService>(context, listen: false);
    final tariffaDefault = auth.currentUser?.tariffa ?? 50.0;
    _tariffaController.text = tariffaDefault.toStringAsFixed(0);
    if (auth.currentUser != null) {
      _selectedWorkerIds = [auth.currentUser!.uid];
    }
    _loadData();
    if (isEditing) _prefillForm();
  }

  void _prefillForm() {
    final apt = widget.appointment!;
    _titoloController.text = apt.titolo;
    _noteController.text = apt.note ?? '';
    _tariffaController.text = apt.tariffa.toString();
    _fatturato = apt.fatturato;
    _pagato = apt.pagato;
    _isSocio = apt.isSocio;
    _selectedWorkerIds = List.from(apt.workerIds);
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
            final m = clients.where((c) => c.id == widget.appointment!.clientId);
            if (m.isNotEmpty) _selectedClient = m.first;
          }
        }));
    FirebaseFirestore.instance.collection('users').get().then((snap) {
      setState(() {
        _allUsers = snap.docs
            .map((d) => UfficioUser.fromFirestore(d.data(), d.id))
            .toList();
      });
    });
  }

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
      final diff = (t.hour * 60 + t.minute) - (_oraInizio.hour * 60 + _oraInizio.minute);
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
  double get _tariffaBase => double.tryParse(_tariffaController.text) ?? 0;
  double get _tariffaFinale => _isSocio ? _tariffaBase : _tariffaBase * 1.15;
  double get _totale => _oreTotali * _tariffaFinale;

  Color _userColor(UfficioUser u) {
    try {
      return Color(int.parse(
          'FF${(u.personaColor ?? '#607D8B').replaceAll('#', '')}',
          radix: 16));
    } catch (_) {
      return Colors.blueGrey;
    }
  }

  // ── Dialog conferma conflitto ─────────────────────────────────────────
  Future<bool> _showConflictDialog({
    required String titolo,
    required String messaggio,
    required Color colore,
  }) async {
    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colore.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.warning_amber_rounded, color: colore, size: 24),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(titolo,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
        ]),
        content: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colore.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colore.withOpacity(0.25)),
          ),
          child: Text(messaggio,
              style: TextStyle(fontSize: 14, height: 1.5)),
        ),
        actionsPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, false),
                  icon: Icon(Icons.close, size: 16),
                  label: Text('Annulla'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: Icon(Icons.check, size: 16),
                  label: Text('Continua'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colore,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
    return go == true;
  }

  // ── Salva con tutti i check conflitti ────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoom == null) { _err('Seleziona una stanza'); return; }
    if (_selectedClient == null) { _err('Seleziona un cliente'); return; }
    setState(() => _loading = true);

    // Cattura navigator e messenger PRIMA delle operazioni asincrone
    // per evitare l'errore "Trying to render a disposed EngineFlutterView"
    // su Flutter Web quando il widget viene smontato dopo un await.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final inicio = _timeStr(_oraInizio);
      final fine = _timeStr(_oraFine);
      final dataNorm = DateTime(
          _selectedDay.year, _selectedDay.month, _selectedDay.day);
      final excludeId = widget.appointment?.id;

      // 1⃣ Conflitto STANZA
      final roomConflict = await _aptService.checkRoomConflict(
          _selectedRoom!.id!, dataNorm, inicio, fine,
          excludeId: excludeId);
      if (roomConflict != null && mounted) {
        final go = await _showConflictDialog(
          titolo: 'Stanza occupata',
          messaggio:
              '"\u200b${_selectedRoom!.name}" è già occupata in questo orario:\n'
              '"\u200b${roomConflict.titolo}"\n'
              '${roomConflict.oraInizio} – ${roomConflict.oraFine}\n\n'
              'Vuoi creare l\'appuntamento lo stesso?',
          colore: Colors.orange,
        );
        if (!go) { setState(() => _loading = false); return; }
      }

      // 2⃣ Conflitto CLIENTE
      final clientConflict = await _aptService.checkClientConflict(
          _selectedClient!.id!, dataNorm, inicio, fine,
          excludeId: excludeId);
      if (clientConflict != null && mounted) {
        final go = await _showConflictDialog(
          titolo: 'Cliente già impegnato',
          messaggio:
              '"\u200b${_selectedClient!.fullName}" ha già un appuntamento in questo orario:\n'
              '"\u200b${clientConflict.titolo}"\n'
              '${clientConflict.oraInizio} – ${clientConflict.oraFine}\n\n'
              'Vuoi continuare comunque?',
          colore: Colors.red,
        );
        if (!go) { setState(() => _loading = false); return; }
      }

      // 3⃣ Conflitto LAVORATORI (uno per uno)
      final workers = _selectedWorkerIds.isNotEmpty
          ? _selectedWorkerIds
          : [auth.firebaseUser!.uid];

      for (final workerId in workers) {
        final workerConflict = await _aptService.checkWorkerConflict(
            workerId, dataNorm, inicio, fine,
            excludeId: excludeId);
        if (workerConflict != null && mounted) {
          final workerName = _allUsers
              .firstWhere((u) => u.uid == workerId,
                  orElse: () => UfficioUser(
                      uid: workerId,
                      email: workerId,
                      displayName: 'Lavoratore'))
              .displayName ?? 'Lavoratore';
          final go = await _showConflictDialog(
            titolo: 'Lavoratore già occupato',
            messaggio:
                '"\u200b$workerName" ha già un appuntamento in questo orario:\n'
                '"\u200b${workerConflict.titolo}"\n'
                '${workerConflict.oraInizio} – ${workerConflict.oraFine}\n\n'
                'Vuoi assegnarlo comunque?',
            colore: Colors.purple,
          );
          if (!go) { setState(() => _loading = false); return; }
        }
      }

      // ── Tutti i check superati (o confermati) — salva ───────────────────────
      if (isEditing) {
        await _aptService.updateAppointment(widget.appointment!.id!, {
          'titolo': _titoloController.text,
          'data': Timestamp.fromDate(dataNorm),
          'oraInizio': inicio,
          'oraFine': fine,
          'oreTotali': _oreTotali,
          'tariffa': _tariffaFinale,
          'totale': _totale,
          'roomId': _selectedRoom!.id,
          'clientId': _selectedClient!.id,
          'note': _noteController.text,
          'isSocio': _isSocio,
          'workerIds': workers,
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
          tariffa: _tariffaFinale,
          totale: _totale,
          userId: auth.firebaseUser!.uid,
          createdBy: auth.firebaseUser!.uid,
          clientId: _selectedClient!.id!,
          roomId: _selectedRoom!.id!,
          note: _noteController.text,
          isSocio: _isSocio,
          workerIds: workers,
        ));
      }
      // Usa il navigator catturato prima degli await per evitare
      // il crash su Flutter Web con widget già disposed.
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
      );
      if (mounted) setState(() => _loading = false);
    }
  }

  void _err(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  // ── Selettore lavoratori ───────────────────────────────────────────────
  Widget _buildWorkerSelector(Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lavoratori',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 13,
                letterSpacing: 0.5)),
        SizedBox(height: 8),
        if (_allUsers.isEmpty)
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 8),
              Text('Caricamento utenti...',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ]),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allUsers.map((u) {
              final selected = _selectedWorkerIds.contains(u.uid);
              final color = _userColor(u);
              final name = u.displayName ?? u.email;
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _selectedWorkerIds.remove(u.uid);
                  } else {
                    _selectedWorkerIds.add(u.uid);
                  }
                }),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? color.withOpacity(0.15) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? color : Colors.grey[300]!,
                      width: selected ? 2.0 : 1.0,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: selected ? color : Colors.grey[400],
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? color : Colors.grey[700],
                      ),
                    ),
                    if (selected) ...[
                      SizedBox(width: 4),
                      Icon(Icons.check_circle, size: 14, color: color),
                    ],
                  ]),
                ),
              );
            }).toList(),
          ),
        if (_selectedWorkerIds.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              "Nessun lavoratore selezionato \u2014 verr\u00e0 usato l'utente corrente",
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange[700],
                  fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            isEditing ? 'Modifica Appuntamento' : 'Nuovo Appuntamento'),
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
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                validator: (v) =>
                    v!.isEmpty ? 'Campo obbligatorio' : null,
              ),
              SizedBox(height: 16),

              // NOTE
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Note (Opzionali)',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 32.0),
                    child: Icon(Icons.notes),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              SizedBox(height: 16),

              // DATA
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.05),
                    border:
                        Border.all(color: primary.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today, color: primary, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_selectedDay.day.toString().padLeft(2, '0')}/${_selectedDay.month.toString().padLeft(2, '0')}/${_selectedDay.year}',
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
                          onChanged: _onInizioChanged)),
                  SizedBox(width: 12),
                  Column(children: [
                    Text('Durata',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500)),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: primary.withOpacity(0.2)),
                      ),
                      child: Column(children: [
                        InkWell(
                          onTap: () => setState(() {
                            _durataMinuti =
                                (_durataMinuti + 15).clamp(15, 480);
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
                            _durataMinuti =
                                (_durataMinuti - 15).clamp(15, 480);
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
                          onChanged: _onFineChanged)),
                ],
              ),
              SizedBox(height: 16),

              // STANZA
              DropdownButtonFormField<Room>(
                value: _selectedRoom,
                decoration: InputDecoration(
                  labelText: 'Stanza *',
                  prefixIcon: Icon(Icons.meeting_room),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                items: _rooms.map((r) {
                  final c = Color(int.parse(
                      'FF${r.color.replaceAll("#", "")}',
                      radix: 16));
                  return DropdownMenuItem(
                      value: r,
                      child: Row(children: [
                        Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                                color: c, shape: BoxShape.circle)),
                        SizedBox(width: 8),
                        Text(r.name),
                      ]));
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
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                items: _clients
                    .map((c) => DropdownMenuItem(
                        value: c, child: Text(c.fullName)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedClient = v),
                hint: Text('Seleziona cliente'),
              ),
              SizedBox(height: 16),

              // LAVORATORI
              _buildWorkerSelector(primary),
              SizedBox(height: 16),

              // TOGGLE SOCIO
              Container(
                decoration: BoxDecoration(
                  color: _isSocio
                      ? Colors.green.withOpacity(0.05)
                      : Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isSocio
                        ? Colors.green.withOpacity(0.3)
                        : Colors.orange.withOpacity(0.4),
                  ),
                ),
                child: SwitchListTile(
                  title: Text(
                    _isSocio
                        ? 'Cliente Socio'
                        : 'Cliente Non Socio (+15%)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _isSocio
                          ? Colors.green[700]
                          : Colors.orange[800],
                    ),
                  ),
                  subtitle: Text(
                    _isSocio
                        ? 'Tariffa standard applicata'
                        : 'Supplemento del 15% applicato alla tariffa',
                    style: TextStyle(fontSize: 12),
                  ),
                  secondary: Icon(
                    _isSocio
                        ? Icons.card_membership
                        : Icons.person_off,
                    color: _isSocio
                        ? Colors.green[700]
                        : Colors.orange[800],
                  ),
                  value: _isSocio,
                  activeColor: Colors.green,
                  onChanged: (v) => setState(() => _isSocio = v),
                ),
              ),
              SizedBox(height: 16),

              // TARIFFA
              TextFormField(
                controller: _tariffaController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Tariffa \u20ac/ora (base)',
                  prefixIcon: Icon(Icons.euro),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  helperText: !_isSocio
                      ? 'Tariffa effettiva: \u20ac${_tariffaFinale.toStringAsFixed(2)}/ora (+15%)'
                      : null,
                  helperStyle: TextStyle(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500),
                ),
              ),
              SizedBox(height: 12),

              // TOTALE
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: primary.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_timeStr(_oraInizio)} \u2192 ${_timeStr(_oraFine)}  \u2022  ${_durataLabel()}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                          ),
                          SizedBox(height: 2),
                          Row(children: [
                            Text('Totale stimato',
                                style: TextStyle(
                                    color: primary, fontSize: 13)),
                            if (!_isSocio) ...[
                              SizedBox(width: 6),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.15),
                                  borderRadius:
                                      BorderRadius.circular(4),
                                ),
                                child: Text('+15%',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.orange[800],
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ]),
                        ]),
                    Text('\u20ac ${_totale.toStringAsFixed(2)}',
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
                      title: Text('Fatturato',
                          style: TextStyle(fontSize: 13)),
                      value: _fatturato,
                      activeColor: Colors.orange,
                      dense: true,
                      onChanged: (v) =>
                          setState(() => _fatturato = v!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: CheckboxListTile(
                      title: Text('Pagato',
                          style: TextStyle(fontSize: 13)),
                      value: _pagato,
                      activeColor: Colors.green,
                      dense: true,
                      onChanged: (v) =>
                          setState(() => _pagato = v!),
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
                      isEditing
                          ? 'Salva Modifiche'
                          : 'Crea Appuntamento',
                      style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
