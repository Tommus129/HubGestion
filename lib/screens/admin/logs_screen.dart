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
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      drawer: AppDrawer(),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('logs')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
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

              return Card(
                margin: EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _logColor(type).withOpacity(0.15),
                    child: Icon(_logIcon(type), color: _logColor(type), size: 20),
                  ),
                  title: Text(_logLabel(type),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (type == 'ROLE_CHANGE') ...[
                        Text('Utente: ${data['targetUserId'] ?? '-'}',
                            style: TextStyle(fontSize: 12)),
                        Text(
                          '${data['oldRole']?.toUpperCase() ?? '-'} → ${data['newRole']?.toUpperCase() ?? '-'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                      if (type == 'DELETE_APPOINTMENT')
                        Text('Appuntamento: ${data['targetAppointmentId'] ?? '-'}',
                            style: TextStyle(fontSize: 12)),
                      if (timestamp != null)
                        Text(
                          _formatTimestamp(timestamp),
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  ),
                  trailing: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _logColor(type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _logColor(type).withOpacity(0.3)),
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
      ),
    );
  }

  Color _logColor(String type) {
    switch (type) {
      case 'ROLE_CHANGE': return Colors.purple;
      case 'DELETE_APPOINTMENT': return Colors.red;
      case 'CREATE_USER': return Colors.green;
      default: return Colors.blueGrey;
    }
  }

  IconData _logIcon(String type) {
    switch (type) {
      case 'ROLE_CHANGE': return Icons.manage_accounts;
      case 'DELETE_APPOINTMENT': return Icons.delete;
      case 'CREATE_USER': return Icons.person_add;
      default: return Icons.info;
    }
  }

  String _logLabel(String type) {
    switch (type) {
      case 'ROLE_CHANGE': return 'Cambio Ruolo';
      case 'DELETE_APPOINTMENT': return 'Eliminazione Appuntamento';
      case 'CREATE_USER': return 'Nuovo Utente';
      default: return type;
    }
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} '
           '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }
}
