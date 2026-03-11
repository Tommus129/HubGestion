import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/weekly_calendar.dart';
import '../widgets/app_drawer.dart';
import '../services/auth_service.dart';
import '../models/room.dart';
import '../models/client.dart';
import '../services/room_service.dart';
import '../services/client_service.dart';
import 'appointment_form_screen.dart';
import 'appointment_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedWeek = DateTime.now();

  String? _filterUserId;
  String? _filterRoomId;
  String? _filterClientId;

  List<Map<String, dynamic>> _users = [];
  List<Room> _rooms = [];
  List<Client> _clients = [];
  bool _loadingFilters = true;

  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadFilterData();
  }

  // Tutto one-shot: rooms e clients cambiano raramente, non serve real-time.
  // Questo elimina 2 stream Firestore sempre aperti e il relativo lag.
  Future<void> _loadFilterData() async {
    try {
      final results = await Future.wait([
        _db.collection('users').get(),
        RoomService().getRoomsOnce(),
        ClientService().getClientsOnce(includeArchived: false),
      ]);
      if (!mounted) return;
      final usersSnap = results[0] as QuerySnapshot;
      final rooms = results[1] as List<Room>;
      final clients = results[2] as List<Client>;
      setState(() {
        _users = usersSnap.docs.map((d) => {
          'uid': d.id,
          'displayName': d.data()['displayName'] ?? d.data()['email'] ?? 'Utente',
          'personaColor': d.data()['personaColor'] ?? '#607D8B',
        }).toList();
        _rooms = rooms;
        _clients = clients;
        _loadingFilters = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingFilters = false);
    }
  }

  void _previousWeek() => setState(() =>
      _focusedWeek = _focusedWeek.subtract(const Duration(days: 7)));

  void _nextWeek() => setState(() =>
      _focusedWeek = _focusedWeek.add(const Duration(days: 7)));

  void _goToday() => setState(() => _focusedWeek = DateTime.now());

  String _weekLabel() {
    final monday = _focusedWeek.subtract(Duration(days: _focusedWeek.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    if (monday.month == sunday.month) {
      return '${monday.day} - ${sunday.day} ${_monthName(monday.month)} ${monday.year}';
    }
    return '${monday.day} ${_monthName(monday.month)} - ${sunday.day} ${_monthName(sunday.month)} ${monday.year}';
  }

  String _monthName(int m) {
    const months = ['Gen','Feb','Mar','Apr','Mag','Giu','Lug','Ago','Set','Ott','Nov','Dic'];
    return months[m - 1];
  }

  bool get _hasActiveFilters =>
      _filterUserId != null || _filterRoomId != null || _filterClientId != null;

  void _resetFilters() => setState(() {
    _filterUserId = null;
    _filterRoomId = null;
    _filterClientId = null;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
        actions: [
          if (_hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Rimuovi filtri',
              onPressed: _resetFilters,
            ),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Oggi',
            onPressed: _goToday,
          ),
          // Ricarica filtri manualmente (utile se aggiungi clienti/stanze)
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Aggiorna filtri',
            onPressed: () {
              setState(() => _loadingFilters = true);
              _loadFilterData();
            },
          ),
        ],
      ),
      drawer: AppDrawer(),
      body: Column(
        children: [
          Container(
            color: Colors.grey[50],
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _loadingFilters
                  ? const SizedBox(
                      height: 32,
                      child: Row(children: [
                        SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('Caricamento filtri...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                    )
                  : Row(
                children: [
                  _FilterChip(
                    icon: Icons.person,
                    label: _filterUserId != null
                        ? (_users.firstWhere((u) => u['uid'] == _filterUserId,
                            orElse: () => {'displayName': 'Utente'})['displayName'] as String)
                        : 'Persona',
                    active: _filterUserId != null,
                    color: primary,
                    onTap: () => _showUserPicker(context, primary),
                    onClear: _filterUserId != null
                        ? () => setState(() => _filterUserId = null)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    icon: Icons.meeting_room,
                    label: _filterRoomId != null
                        ? (_rooms.firstWhere((r) => r.id == _filterRoomId,
                            orElse: () => Room(name: 'Stanza', color: '#607D8B')).name)
                        : 'Stanza',
                    active: _filterRoomId != null,
                    color: primary,
                    onTap: () => _showRoomPicker(context, primary),
                    onClear: _filterRoomId != null
                        ? () => setState(() => _filterRoomId = null)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    icon: Icons.business_center,
                    label: _filterClientId != null
                        ? (_clients.firstWhere((c) => c.id == _filterClientId,
                            orElse: () => Client(nome: 'Cliente', cognome: '')).fullName)
                        : 'Cliente',
                    active: _filterClientId != null,
                    color: primary,
                    onTap: () => _showClientPicker(context, primary),
                    onClear: _filterClientId != null
                        ? () => setState(() => _filterClientId = null)
                        : null,
                  ),
                  if (_hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _resetFilters,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          Icon(Icons.clear_all, size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Text('Reset', style: TextStyle(fontSize: 12, color: Colors.red)),
                        ]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            color: primary.withOpacity(0.05),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousWeek,
                  color: primary,
                ),
                Text(
                  _weekLabel(),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primary),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextWeek,
                  color: primary,
                ),
              ],
            ),
          ),
          Expanded(
            child: WeeklyCalendar(
              focusedWeek: _focusedWeek,
              filterUserId: _filterUserId,
              filterRoomId: _filterRoomId,
              filterClientId: _filterClientId,
              onTapAppointment: (apt) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AppointmentDetailScreen(appointment: apt),
                ),
              ),
              onTapSlot: (dateTime) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AppointmentFormScreen(selectedDay: dateTime),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AppointmentFormScreen(selectedDay: DateTime.now()),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo'),
      ),
    );
  }

  void _showUserPicker(BuildContext context, Color primary) {
    if (_users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun utente disponibile')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PickerSheet(
        title: 'Filtra per Persona',
        children: _users.map((u) {
          final hex = (u['personaColor'] as String).replaceAll('#', '');
          Color c;
          try { c = Color(int.parse('FF$hex', radix: 16)); }
          catch (_) { c = Colors.blueGrey; }
          final displayName = u['displayName'] as String? ?? 'Utente';
          return _PickerItem(
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: c,
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            label: displayName,
            selected: _filterUserId == u['uid'],
            onTap: () {
              setState(() => _filterUserId =
                  _filterUserId == u['uid'] ? null : u['uid'] as String);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showRoomPicker(BuildContext context, Color primary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PickerSheet(
        title: 'Filtra per Stanza',
        children: _rooms.map((r) {
          Color c;
          try { c = Color(int.parse('FF${r.color.replaceAll("#", "")}', radix: 16)); }
          catch (_) { c = Colors.grey; }
          return _PickerItem(
            leading: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.meeting_room, color: Colors.white, size: 16),
            ),
            label: r.name,
            selected: _filterRoomId == r.id,
            onTap: () {
              setState(() => _filterRoomId = _filterRoomId == r.id ? null : r.id);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showClientPicker(BuildContext context, Color primary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PickerSheet(
        title: 'Filtra per Cliente',
        children: _clients.map((cl) => _PickerItem(
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: primary,
            child: Text(cl.nome[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          label: cl.fullName,
          selected: _filterClientId == cl.id,
          onTap: () {
            setState(() => _filterClientId = _filterClientId == cl.id ? null : cl.id);
            Navigator.pop(context);
          },
        )).toList(),
      ),
    );
  }
}

// ── FILTER CHIP ──────────────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : Colors.grey.shade300,
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? color : Colors.grey),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                color: active ? color : Colors.grey[700],
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 13, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── PICKER SHEET ───────────────────────────────────────────────────────────────────────────
class _PickerSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _PickerSheet({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }
}

// ── PICKER ITEM ────────────────────────────────────────────────────────────────────────────
class _PickerItem extends StatelessWidget {
  final Widget leading;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PickerItem({
    required this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: leading,
      title: Text(label,
          style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      trailing: selected
          ? Icon(Icons.check_circle, color: primary)
          : Icon(Icons.radio_button_unchecked, color: Colors.grey[300]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      tileColor: selected ? primary.withOpacity(0.05) : null,
      onTap: onTap,
    );
  }
}
