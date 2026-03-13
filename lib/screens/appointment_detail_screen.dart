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
  const AppointmentDetailScreen({super.key, required this.appointment});

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  final AppointmentService _aptService = AppointmentService();
  Client? _client;
  Room? _room;

  Map<String, Map<String, dynamic>> _workersData = {};

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final apt = widget.appointment;

    final client = await ClientService().getClientById(apt.clientId);
    if (mounted && client != null) setState(() => _client = client);

    RoomService().getRooms().listen((rooms) {
      final match = rooms.where((r) => r.id == apt.roomId);
      if (match.isNotEmpty && mounted) setState(() => _room = match.first);
    });

    final seen = <String>{};
    final ids = <String>[];
    if (apt.userId.isNotEmpty && seen.add(apt.userId)) ids.add(apt.userId);
    for (final w in apt.workerIds) {
      if (w.isNotEmpty && seen.add(w)) ids.add(w);
    }

    final db = FirebaseFirestore.instance;
    final result = <String, Map<String, dynamic>>{};
    for (final userId in ids) {
      try {
        final doc = await db.collection('users').doc(userId).get();
        if (doc.exists) {
          final d = doc.data()!;
          final name = d['displayName']?.toString().isNotEmpty == true
              ? d['displayName']
              : (d['email'] ?? 'Utente');
          final hex = (d['personaColor'] ?? '607D8B').toString().replaceAll('#', '');
          Color color;
          try {
            color = Color(int.parse('FF$hex', radix: 16));
          } catch (_) {
            color = Colors.blueGrey;
          }
          result[userId] = {'name': name, 'color': color, 'isOwner': userId == apt.userId};
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _workersData = result);
  }

  Future<void> _toggleFatturato() async {
    await _aptService.updateAppointment(widget.appointment.id!, {
      'fatturato': !widget.appointment.fatturato,
    });
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _togglePagato() async {
    await _aptService.updateAppointment(widget.appointment.id!, {
      'pagato': !widget.appointment.pagato,
    });
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _deleteAppointment(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina Appuntamento'),
        content: Text('Sei sicuro di voler eliminare "${widget.appointment.titolo}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _aptService.deleteAppointment(widget.appointment.id!);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary   = Theme.of(context).colorScheme.primary;
    final auth      = Provider.of<AuthService>(context);
    final user      = auth.currentUser;
    final apt       = widget.appointment;
    final canEdit   = user?.isAdmin == true || user?.uid == apt.userId;
    final roomColor = _room != null
        ? Color(int.parse('FF${_room!.color.replaceAll("#", "")}', radix: 16))
        : primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettaglio'),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit),
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
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteAppointment(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(apt.titolo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(DateHelpers.formatDate(apt.data), style: const TextStyle(color: Colors.grey)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('${apt.oraInizio} - ${apt.oraFine}', style: const TextStyle(color: Colors.grey)),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.group, color: primary, size: 20),
                      const SizedBox(width: 8),
                      const Text('Lavoratori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${_workersData.length}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primary)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    if (_workersData.isEmpty)
                      const Text('Caricamento...', style: TextStyle(color: Colors.grey))
                    else
                      ..._workersData.entries.map((entry) {
                        final name    = entry.value['name'] as String;
                        final color   = entry.value['color'] as Color;
                        final isOwner = entry.value['isOwner'] as bool;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: color,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                              if (isOwner)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: primary.withValues(alpha: 0.3)),
                                  ),
                                  child: Text('Responsabile',
                                      style: TextStyle(fontSize: 11, color: primary, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.notes, color: primary, size: 20),
                      const SizedBox(width: 8),
                      const Text('Note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ]),
                    const SizedBox(height: 10),
                    if (apt.note != null && apt.note!.trim().isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Text(apt.note!, style: const TextStyle(fontSize: 15, height: 1.5)),
                      )
                    else
                      Row(children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 6),
                        Text('Nessuna nota',
                            style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
                      ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_room != null) ...[
              Card(
                child: ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: roomColor, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.meeting_room, color: Colors.white, size: 20),
                  ),
                  title: const Text('Stanza'),
                  subtitle: Text(_room!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_client != null) ...[
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primary,
                    child: Text(_client!.nome[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white)),
                  ),
                  title: const Text('Cliente'),
                  subtitle: Text(_client!.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: _client!.telefono != null && _client!.telefono!.isNotEmpty
                      ? Icon(Icons.phone, color: primary)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Riepilogo Economico',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    _infoRow('Ore totali', '${apt.oreTotali}h'),
                    _infoRow('Tariffa', '${DateHelpers.formatCurrency(apt.tariffa)}/ora'),
                    const Divider(),
                    _infoRow('Totale', DateHelpers.formatCurrency(apt.totale), bold: true, color: primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Stato Pagamento',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
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
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? activeColor : Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? activeColor : Colors.grey, size: 28),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
              color: active ? activeColor : Colors.grey,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            )),
          ],
        ),
      ),
    );
  }
}
