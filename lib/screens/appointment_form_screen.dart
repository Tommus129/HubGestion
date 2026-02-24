import 'package:flutter/material.dart';
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
  final _tariffaController = TextEditingController(text: '50');
  final _oreTotaliController = TextEditingController();
  final _durataController = TextEditingController(text: '1');

  final AppointmentService _aptService = AppointmentService();
  final RoomService _roomService = RoomService();
  final ClientService _clientService = ClientService();

  TimeOfDay _oraInizio = TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _oraFine = TimeOfDay(hour: 10, minute: 0);
  Room? _selectedRoom;
  Client? _selectedClient;
  bool _loading = false;
  bool _fatturato = false;
  bool _pagato = false;
  double _durata = 1.0; // ore

  List<Room> _rooms = [];
  List<Client> _clients = [];

  bool get isEditing => widget.appointment != null;

  @override
  void initState() {
    super.initState();
    _loadData();
    if (isEditing) _prefillForm();
    _updateFine();
  }

  void _prefillForm() {
    final apt = widget.appointment!;
    _titoloController.text = apt.titolo;
    _tariffaController.text = apt.tariffa.toString();
    _fatturato = apt.fatturato;
    _pagato = apt.pagato;
    final s = apt.oraInizio.split(':');
    final e = apt.oraFine.split(':');
    if (s.length == 2) _oraInizio = TimeOfDay(hour: int.parse(s[0]), minute: int.parse(s[1]));
    if (e.length == 2) _oraFine = TimeOfDay(hour: int.parse(e[0]), minute: int.parse(e[1]));
    _durata = apt.oreTotali;
    _durataController.text = apt.oreTotali.toString();
  }

  void _loadData() {
    _roomService.getRooms().listen((rooms) {
      setState(() {
        _rooms = rooms;
        if (isEditing && _selectedRoom == null) {
          final match = rooms.where((r) => r.id == widget.appointment!.roomId);
          if (match.isNotEmpty) _selectedRoom = match.first;
        }
      });
    });
    _clientService.getClients().listen((clients) {
      setState(() {
        _clients = clients;
        if (isEditing && _selectedClient == null) {
          final match = clients.where((c) => c.id == widget.appointment!.clientId);
          if (match.isNotEmpty) _selectedClient = match.first;
        }
      });
    });
  }

  String _timeToString(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // Auto-calcola ora fine da inizio + durata
  void _updateFine() {
    final totalMinutes = _oraInizio.hour * 60 + _oraInizio.minute + (_durata * 60).round();
    _oraFine = TimeOfDay(hour: (totalMinutes ~/ 60) % 24, minute: totalMinutes % 60);
    _oreTotaliController.text = _durata.toStringAsFixed(1);
    setState(() {});
  }

  // Auto-calcola durata da inizio e fine
  void _updateDurataFromFine() {
    final startMin = _oraInizio.hour * 60 + _oraInizio.minute;
    final endMin = _oraFine.hour * 60 + _oraFine.minute;
    final diff = (endMin - startMin) / 60.0;
    if (diff > 0) {
      _durata = diff;
      _durataController.text = diff.toStringAsFixed(1);
      _oreTotaliController.text = diff.toStringAsFixed(1);
    }
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoom == null) { _showError('Seleziona una stanza'); return; }
    if (_selectedClient == null) { _showError('Seleziona un cliente'); return; }

    setState(() => _loading = true);
    final auth = Provider.of<AuthService>(context, listen: false);

    final conflict = await _aptService.checkRoomConflict(
      _selectedRoom!.id!, widget.selectedDay,
      _timeToString(_oraInizio), _timeToString(_oraFine),
      excludeId: widget.appointment?.id,
    );

    if (conflict != null && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Row(children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8), Text('Conflitto Stanza'),
          ]),
          content: Text(
            '${_selectedRoom!.name} già occupata da\n"${conflict.titolo}"\n'
            '(${conflict.oraInizio} - ${conflict.oraFine})\n\nContinuare?'
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annulla')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text('Continua'),
            ),
          ],
        ),
      );
      if (proceed != true) { setState(() => _loading = false); return; }
    }

    final ore = double.tryParse(_oreTotaliController.text) ?? _durata;
    final tariffa = double.tryParse(_tariffaController.text) ?? 0.0;

    try {
      if (isEditing) {
        await _aptService.updateAppointment(widget.appointment!.id!, {
          'titolo': _titoloController.text,
          'oraInizio': _timeToString(_oraInizio),
          'oraFine': _timeToString(_oraFine),
          'oreTotali': ore,
          'tariffa': tariffa,
          'totale': ore * tariffa,
          'roomId': _selectedRoom!.id,
          'clientId': _selectedClient!.id,
          'fatturato': _fatturato,
          'pagato': _pagato,
        });
      } else {
        await _aptService.createAppointment(Appointment(
          titolo: _titoloController.text,
          data: widget.selectedDay,
          oraInizio: _timeToString(_oraInizio),
          oraFine: _timeToString(_oraFine),
          oreTotali: ore,
          tariffa: tariffa,
          totale: ore * tariffa,
          userId: auth.firebaseUser!.uid,
          createdBy: auth.firebaseUser!.uid,
          clientId: _selectedClient!.id!,
          roomId: _selectedRoom!.id!,
          fatturato: _fatturato,
          pagato: _pagato,
        ));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Errore: $e');
      setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ore = double.tryParse(_oreTotaliController.text) ?? 0;
    final tariffa = double.tryParse(_tariffaController.text) ?? 0;
    final totale = ore * tariffa;

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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (v) => v!.isEmpty ? 'Campo obbligatorio' : null,
              ),
              SizedBox(height: 16),

              // DATA
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(8),
                  color: theme.colorScheme.primary.withOpacity(0.05),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                  SizedBox(width: 12),
                  Text(
                    '${widget.selectedDay.day.toString().padLeft(2,'0')}/'
                    '${widget.selectedDay.month.toString().padLeft(2,'0')}/'
                    '${widget.selectedDay.year}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ]),
              ),
              SizedBox(height: 16),

              // ORA INIZIO + DURATA → auto calcola FINE
              Text('Orario', style: TextStyle(fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary)),
              SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TimePicker24h(
                    label: 'Inizio',
                    initialTime: _oraInizio,
                    onChanged: (t) {
                      setState(() => _oraInizio = t);
                      _updateFine();
                    },
                  ),
                ),
                SizedBox(width: 8),
                // DURATA (ore)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Durata', style: TextStyle(fontSize: 11,
                          color: theme.colorScheme.primary)),
                      SizedBox(height: 4),
                      Row(children: [
                        Expanded(
                          child: Slider(
                            value: _durata.clamp(0.25, 8.0),
                            min: 0.25, max: 8.0, divisions: 31,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (v) {
                              setState(() => _durata = double.parse(v.toStringAsFixed(2)));
                              _updateFine();
                            },
                          ),
                        ),
                        Text('${_durata.toStringAsFixed(1)}h',
                            style: TextStyle(fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary)),
                      ]),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TimePicker24h(
                    label: 'Fine',
                    initialTime: _oraFine,
                    onChanged: (t) {
                      setState(() => _oraFine = t);
                      _updateDurataFromFine();
                    },
                  ),
                ),
              ]),
              SizedBox(height: 16),

              // STANZA
              DropdownButtonFormField<Room>(
                value: _selectedRoom,
                decoration: InputDecoration(
                  labelText: 'Stanza *',
                  prefixIcon: Icon(Icons.meeting_room),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: _rooms.map((r) {
                  final color = Color(int.parse('FF${r.color.replaceAll("#", "")}', radix: 16));
                  return DropdownMenuItem(
                    value: r,
                    child: Row(children: [
                      Container(width: 14, height: 14,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      SizedBox(width: 8), Text(r.name),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: _clients.map((c) => DropdownMenuItem(
                  value: c, child: Text(c.fullName),
                )).toList(),
                onChanged: (v) => setState(() => _selectedClient = v),
                hint: Text('Seleziona cliente'),
              ),
              SizedBox(height: 16),

              // ORE + TARIFFA
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _oreTotaliController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Ore totali',
                    prefixIcon: Icon(Icons.timer),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )),
                SizedBox(width: 8),
                Expanded(child: TextFormField(
                  controller: _tariffaController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Tariffa €/ora',
                    prefixIcon: Icon(Icons.euro),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )),
              ]),
              SizedBox(height: 12),

              // TOTALE
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Totale stimato:',
                        style: TextStyle(color: theme.colorScheme.primary)),
                    Text('€ ${totale.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        )),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // FATTURATO / PAGATO
              if (isEditing) ...[
                Row(children: [
                  Expanded(child: CheckboxListTile(
                    title: Text('Fatturato'),
                    value: _fatturato,
                    activeColor: Colors.orange,
                    onChanged: (v) => setState(() => _fatturato = v!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  )),
                  SizedBox(width: 8),
                  Expanded(child: CheckboxListTile(
                    title: Text('Pagato'),
                    value: _pagato,
                    activeColor: Colors.green,
                    onChanged: (v) => setState(() => _pagato = v!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  )),
                ]),
                SizedBox(height: 16),
              ],

              // SALVA
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _save,
                  icon: _loading
                      ? SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Icon(isEditing ? Icons.save : Icons.add),
                  label: Text(
                    isEditing ? 'Salva Modifiche' : 'Crea Appuntamento',
                    style: TextStyle(fontSize: 16),
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
