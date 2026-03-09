import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment.dart';
import '../models/client.dart';
import '../models/room.dart';
import '../services/appointment_service.dart';
import '../services/client_service.dart';
import '../services/room_service.dart';
import '../services/auth_service.dart';
import '../utils/date_helpers.dart';
import 'appointment_form_screen.dart';

class AppointmentDetailScreen extends StatefulWidget {
  final Appointment appointment;
  AppointmentDetailScreen({required this.appointment});

  @override
  _AppointmentDetailScreenState createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  final AppointmentService _aptService = AppointmentService();
  Client? _client;
  Room? _room;
  String? _creatorName;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    ClientService().getClients(includeArchived: true).listen((clients) {
      final match = clients.where((c) => c.id == widget.appointment.clientId);
      if (match.isNotEmpty && mounted) setState(() => _client = match.first);
    });
    RoomService().getRooms().listen((rooms) {
      final match = rooms.where((r) => r.id == widget.appointment.roomId);
      if (match.isNotEmpty && mounted) setState(() => _room = match.first);
    });

    // Recupera il nome del creatore (utente)
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.appointment.userId).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _creatorName = data?['displayName'] ?? data?['email'] ?? 'Utente sconosciuto';
        });
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _toggleFatturato() async {
    await _aptService.updateAppointment(widget.appointment.id!, {
      'fatturato': !widget.appointment.fatturato,
    });
    Navigator.pop(context);
  }

  Future<void> _togglePagato() async {
    await _aptService.updateAppointment(widget.appointment.id!, {
      'pagato': !widget.appointment.pagato,
    });
    Navigator.pop(context);
  }

  Future<void> _deleteAppointment(BuildContext context) async {
    final primary = Theme.of(context).colorScheme.primary;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Elimina Appuntamento'),
        content: Text('Sei sicuro di voler eliminare "${widget.appointment.titolo}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annulla')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _aptService.deleteAppointment(widget.appointment.id!);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final apt = widget.appointment;
    final canEdit = user?.isAdmin == true || user?.uid == apt.userId;
    final roomColor = _room != null
        ? Color(int.parse('FF${_room!.color.replaceAll("#", "")}', radix: 16))
        : primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('Dettaglio'),
        actions: [
          if (canEdit)
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => AppointmentFormScreen(
                    selectedDay: apt.data,
                    appointment: apt,
                  ),
                ),
              ),
            ),
          if (canEdit)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => _deleteAppointment(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER CARD
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(apt.titolo,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      SizedBox(width: 6),
                      Text(DateHelpers.formatDate(apt.data),
                          style: TextStyle(color: Colors.grey)),
                    ]),
                    SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey),
                      SizedBox(width: 6),
                      Text('${apt.oraInizio} - ${apt.oraFine}',
                          style: TextStyle(color: Colors.grey)),
                    ]),
                    SizedBox(height: 12),
                    Divider(height: 1),
                    SizedBox(height: 12),
                    Row(children: [
                      Icon(Icons.person_pin, size: 16, color: primary),
                      SizedBox(width: 6),
                      Text('Creato da: ', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      Text(_creatorName ?? 'Caricamento...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ]),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),

            // NOTE
            if (apt.note != null && apt.note!.isNotEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notes, color: primary, size: 20),
                          SizedBox(width: 8),
                          Text('Note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(apt.note!, style: TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
              ),
            if (apt.note != null && apt.note!.isNotEmpty)
              SizedBox(height: 8),

            // STANZA
            if (_room != null)
              Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: roomColor, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.meeting_room, color: Colors.white, size: 20),
                  ),
                  title: Text('Stanza'),
                  subtitle: Text(_room!.name,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            SizedBox(height: 8),

            // CLIENTE
            if (_client != null)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primary,
                    child: Text(_client!.nome[0].toUpperCase(),
                        style: TextStyle(color: Colors.white)),
                  ),
                  title: Text('Cliente'),
                  subtitle: Text(_client!.fullName,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: _client!.telefono != null &&
                          _client!.telefono!.isNotEmpty
                      ? Icon(Icons.phone, color: primary)
                      : null,
                ),
              ),
            SizedBox(height: 8),

            // ECONOMICO
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Riepilogo Economico',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 12),
                    _infoRow('Ore totali', '${apt.oreTotali}h'),
                    _infoRow('Tariffa', '${DateHelpers.formatCurrency(apt.tariffa)}/ora'),
                    Divider(),
                    _infoRow('Totale', DateHelpers.formatCurrency(apt.totale),
                        bold: true, color: primary),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8),

            // STATO PAGAMENTO
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stato Pagamento',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statusButton(
                          label: 'Fatturato',
                          active: apt.fatturato,
                          activeColor: Colors.orange,
                          icon: Icons.receipt,
                          onTap: canEdit ? _toggleFatturato : null,
                        ),
                        _statusButton(
                          label: 'Pagato',
                          active: apt.pagato,
                          activeColor: Colors.green,
                          icon: Icons.check_circle,
                          onTap: canEdit ? _togglePagato : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey)),
          Text(value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: color,
                fontSize: bold ? 16 : 14,
              )),
        ],
      ),
    );
  }

  Widget _statusButton({
    required String label,
    required bool active,
    required Color activeColor,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: active ? activeColor.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? activeColor : Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? activeColor : Colors.grey, size: 28),
            SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  color: active ? activeColor : Colors.grey,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }
}
