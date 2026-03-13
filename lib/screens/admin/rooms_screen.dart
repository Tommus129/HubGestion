import 'package:flutter/material.dart';
import '../../models/room.dart';
import '../../services/room_service.dart';
import '../../widgets/app_drawer.dart';

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final roomService = RoomService();

    return Scaffold(
      appBar: AppBar(title: const Text('Stanze')),
      drawer: AppDrawer(),
      body: StreamBuilder<List<Room>>(
        stream: roomService.getRooms(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.meeting_room, size: 64, color: Color(0xFFBDBDBD)),
                  SizedBox(height: 16),
                  Text('Nessuna stanza', style: TextStyle(color: Colors.grey, fontSize: 18)),
                  SizedBox(height: 8),
                  Text('Crea la prima stanza con il bottone +', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          final rooms = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rooms.length,
            itemBuilder: (context, i) {
              final room = rooms[i];
              final color = Color(int.parse('FF${room.color.replaceAll("#", "")}', radix: 16));
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.meeting_room, color: Colors.white),
                  ),
                  title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(room.capacity != null ? 'Capacità: ${room.capacity} persone' : room.note ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: primary),
                        onPressed: () => _showRoomDialog(context, primary, room: room),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(context, room),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Builder(
        builder: (context) => FloatingActionButton.extended(
          onPressed: () => _showRoomDialog(context, Theme.of(context).colorScheme.primary),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Nuova Stanza', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  void _showRoomDialog(BuildContext context, Color primary, {Room? room}) {
    final nameController = TextEditingController(text: room?.name ?? '');
    final capacityController = TextEditingController(text: room?.capacity?.toString() ?? '');
    final noteController = TextEditingController(text: room?.note ?? '');
    String selectedColor = room?.color ?? '#4ECDC4';

    final colors = [
      '#4ECDC4', '#FF6B6B', '#45B7D1', '#96CEB4',
      '#FFEAA7', '#DDA0DD', '#98D8C8', '#F7DC6F',
      '#BB8FCE', '#85C1E9',
    ];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(room == null ? 'Nuova Stanza' : 'Modifica Stanza'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nome stanza *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: capacityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Capacità (opzionale)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: 'Note (opzionale)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Colore:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((c) {
                    final col = Color(int.parse('FF${c.replaceAll("#", "")}', radix: 16));
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                          border: selectedColor == c ? Border.all(color: Colors.black, width: 3) : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                final newRoom = Room(
                  id: room?.id,
                  name: nameController.text,
                  color: selectedColor,
                  capacity: int.tryParse(capacityController.text),
                  note: noteController.text,
                );
                if (room == null) {
                  await RoomService().createRoom(newRoom);
                } else {
                  await RoomService().updateRoom(room.id!, newRoom.toFirestore());
                }
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
              ),
              child: Text(room == null ? 'Crea' : 'Salva'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Room room) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina Stanza'),
        content: Text('Vuoi eliminare "${room.name}"? Gli appuntamenti esistenti non saranno eliminati.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              await RoomService().deleteRoom(room.id!);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}
