import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/app_drawer.dart';

class LogsScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Log Sicurezza'),
      ),
      drawer: AppDrawer(),
      body: FutureBuilder<Map<String, String>>(
        // ✅ Prima carichiamo la mappa uid→displayName, poi i log
        future: _loadUserNames(),
        builder: (context, usersSnap) {
          final userNames = usersSnap.data ?? {};

          return StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('logs')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting ||
                  usersSnap.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield, size: 64, color: Colors.grey[300]),
                      SizedBox(height: 16),
                      Text('Nessun log registrato',
                          style: TextStyle(color: Colors.grey, fontSize: 18)),
                    ],
                  ),
                );
              }

              final logs = snapshot.data!.docs;

              return ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: logs.length,
                itemBuilder: (context, i) {
                  final data = logs[i].data() as Map<String, dynamic>;
                  final type = data['type'] ?? 'UNKNOWN';
                  final timestamp = data['timestamp'] != null
                      ? (data['timestamp'] as Timestamp).toDate()
                      : null;

                  // ✅ Risolve uid → nome leggibile
                  final byUserId = data['byUserId'] ?? '';
                  final targetUserId = data['targetUserId'] ?? '';
                  final byName = userNames[byUserId] ?? _shortUid(byUserId);
                  final targetName = userNames[targetUserId] ?? _shortUid(targetUserId);

                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _logColor(type).withOpacity(0.15),
                        child: Icon(_logIcon(type),
                            color: _logColor(type), size: 20),
                      ),
                      title: Text(_logLabel(type),
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ✅ Chi ha eseguito l'azione
                          if (byName.isNotEmpty)
                            Row(children: [
                              Icon(Icons.person_outline,
                                  size: 11, color: Colors.grey),
                              SizedBox(width: 3),
                              Text('Da: $byName',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[700])),
                            ]),

                          if (type == 'ROLE_CHANGE') ...[
                            Row(children: [
                              Icon(Icons.arrow_forward,
                                  size: 11, color: Colors.grey),
                              SizedBox(width: 3),
                              Text('Utente: $targetName',
                                  style: TextStyle(fontSize: 12)),
                            ]),
                            Text(
                              '${(data['oldRole'] ?? '-').toString().toUpperCase()}'
                              ' → '
                              '${(data['newRole'] ?? '-').toString().toUpperCase()}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],

                          if (type == 'DELETE_APPOINTMENT')
                            Text(
                              'Appuntamento: ${data['targetAppointmentId'] ?? '-'}',
                              style: TextStyle(fontSize: 12),
                            ),

                          if (timestamp != null)
                            Text(
                              _formatTimestamp(timestamp),
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                        ],
                      ),
                      trailing: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _logColor(type).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: _logColor(type).withOpacity(0.3)),
                        ),
                        child: Text(
                          type.replaceAll('_', ' '),
                          style: TextStyle(
                            fontSize: 10,
                            color: _logColor(type),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ✅ Carica una volta sola uid→displayName da Firestore
  Future<Map<String, String>> _loadUserNames() async {
    final snap = await _firestore.collection('users').get();
    return {
      for (final doc in snap.docs)
        doc.id: (doc.data()['displayName']?.toString().isNotEmpty == true
            ? doc.data()['displayName']
            : doc.data()['email']) ?? doc.id
    };
  }

  // ✅ Fallback: mostra solo i primi 8 caratteri dell'uid
  String _shortUid(String uid) =>
      uid.length > 8 ? '${uid.substring(0, 8)}…' : uid;

  Color _logColor(String type) {
    switch (type) {
      case 'ROLE_CHANGE':        return Colors.purple;
      case 'DELETE_APPOINTMENT': return Colors.red;
      case 'CREATE_USER':        return Colors.green;
      default:                   return Colors.blueGrey;
    }
  }

  IconData _logIcon(String type) {
    switch (type) {
      case 'ROLE_CHANGE':        return Icons.manage_accounts;
      case 'DELETE_APPOINTMENT': return Icons.delete;
      case 'CREATE_USER':        return Icons.person_add;
      default:                   return Icons.info;
    }
  }

  String _logLabel(String type) {
    switch (type) {
      case 'ROLE_CHANGE':        return 'Cambio Ruolo';
      case 'DELETE_APPOINTMENT': return 'Eliminazione Appuntamento';
      case 'CREATE_USER':        return 'Nuovo Utente';
      default:                   return type;
    }
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
           '${dt.month.toString().padLeft(2, '0')}/'
           '${dt.year} '
           '${dt.hour.toString().padLeft(2, '0')}:'
           '${dt.minute.toString().padLeft(2, '0')}';
  }
}
