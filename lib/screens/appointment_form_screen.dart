import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/appointment.dart';
import '../models/room.dart';
import '../models/client.dart';
import '../services/appointment_service.dart';
import '../services/room_service.dart';
import '../services/client_service.dart';
import '../services/auth_service.dart';

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
  final _tariffaController = TextEditingController();
  final _oreTotaliController = TextEditingController();

  final AppointmentService _aptService = AppointmentService();
  final RoomService _roomService = RoomService();
  final ClientService _clientService = ClientService();

  TimeOfDay _oraInizio = TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _oraFine = TimeOfDay(hour: 10, minute: 0);
  Room? _selectedRoom;
  Client? _selectedClient;
  bool _loading = false;

  List<Room> _rooms = [];
  List<Client> _clients = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.appointment != null) {
      final apt = widget.appointment!;
      _titoloController.text = apt.titolo;
      _tariffaController.text = apt.tariffa.toString();
      _oreTotaliController.text = apt.oreTotali.toString();
    }
    _tariffaController.text = '50';
    _updateOreTotali();
  }

  void _loadData() async {
    _roomService.getRooms().listen((rooms) => setState(() => _rooms = rooms));
    _clientService.getClients().listen((clients) => setState(() => _clients = clients));
  }

  String _timeToString(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _updateOreTotali() {
    final start = _oraInizio.hour * 60 + _oraInizio.minute;
    final end = _oraFine.hour * 60 + _oraFine.minute;
    final diff = (end - start) / 60.0;
    if (diff > 0) _oreTotaliController.text = diff.toStringAsFixed(1);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Seleziona una stanza')));
      return;
    }
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Seleziona un cliente')));
      return;
    }

    setState(() => _loading = true);
    final auth = Provider.of<AuthService>(context, listen: false);

    // Check conflitto
    final conflict = await _aptService.checkRoomConflict(
      _selectedRoom!.id!,
      widget.selectedDay,
      _timeToString(_oraInizio),
      _timeToString(_oraFine),
    );

    if (conflict != null && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('⚠️ Conflitto Stanza'),
          content: Text('${_selectedRoom!.name} è già occupata da "${conflict.titolo}" (${conflict.oraInizio} - ${conflict.oraFine}). Continuare comunque?'),
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
      if (proceed != true) {
        setState(() => _loading = false);
        return;
      }
    }

    final ore = double.tryParse(_oreTotaliController.text) ?? 1.0;
    final tariffa = double.tryParse(_tariffaController.text) ?? 0.0;

    final appointment = Appointment(
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
    );

    await _aptService.createAppointment(appointment);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nuovo Appuntamento'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
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
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.teal),
                    SizedBox(width: 12),
                    Text('Data: ${widget.selectedDay.day}/${widget.selectedDay.month}/${widget.selectedDay.year}',
                        style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // ORA INIZIO / FINE
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: _oraInizio);
                        if (t != null) { setState(() { _oraInizio = t; _updateOreTotali(); }); }
                      },
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(Icons.access_time, color: Colors.teal),
                          SizedBox(width: 8),
                          Text('Inizio: ${_timeToString(_oraInizio)}'),
                        ]),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: _oraFine);
                        if (t != null) { setState(() { _oraFine = t; _updateOreTotali(); }); }
                      },
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(Icons.access_time_filled, color: Colors.teal),
                          SizedBox(width: 8),
                          Text('Fine: ${_timeToString(_oraFine)}'),
                        ]),
                      ),
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
                  prefixIcon: Icon(Icons.room),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: _rooms.map((r) => DropdownMenuItem(
                  value: r,
                  child: Row(children: [
                    Container(width: 12, height: 12,
                        decoration: BoxDecoration(color: Color(int.parse('FF${r.color.replaceAll("#", "")}', radix: 16)), shape: BoxShape.circle)),
                    SizedBox(width: 8),
                    Text(r.name),
                  ]),
                )).toList(),
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
                  value: c,
                  child: Text(c.fullName),
                )).toList(),
                onChanged: (v) => setState(() => _selectedClient = v),
                hint: Text('Seleziona cliente'),
              ),
              SizedBox(height: 16),

              // ORE + TARIFFA
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _oreTotaliController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Ore totali',
                        prefixIcon: Icon(Icons.timer),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _tariffaController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Tariffa €/ora',
                        prefixIcon: Icon(Icons.euro),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 32),

              // BOTTONE SALVA
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _loading ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Icon(Icons.save),
                  label: Text('Salva Appuntamento', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
