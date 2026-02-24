import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_drawer.dart';

class UsersRolesScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final currentUser = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Gestione Utenti'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      drawer: AppDrawer(),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('Nessun utente trovato'));
          }

          final users = snapshot.data!.docs
              .map((d) => UfficioUser.fromFirestore(d.data() as Map<String, dynamic>, d.id))
              .toList();

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, i) {
              final user = users[i];
              final isCurrentUser = user.uid == currentUser?.uid;
              final isSuperAdmin = user.role == 'superadmin';

              return Card(
                margin: EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // AVATAR
                      CircleAvatar(
                        backgroundColor: _roleColor(user.role),
                        child: Text(
                          (user.displayName ?? user.email).isNotEmpty
                              ? (user.displayName ?? user.email)[0].toUpperCase()
                              : 'U',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(width: 12),

                      // INFO
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  user.displayName ?? 'Senza nome',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                if (isCurrentUser) ...[
                                  SizedBox(width: 6),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.teal[50],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('Tu', style: TextStyle(fontSize: 10, color: Colors.teal)),
                                  ),
                                ],
                              ],
                            ),
                            Text(user.email, style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),

                      // RUOLO BADGE / DROPDOWN
                      if (isSuperAdmin || isCurrentUser)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _roleColor(user.role).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _roleColor(user.role).withOpacity(0.4)),
                          ),
                          child: Text(
                            user.role.toUpperCase(),
                            style: TextStyle(
                              color: _roleColor(user.role),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        )
                      else
                        DropdownButton<String>(
                          value: user.role,
                          underline: SizedBox(),
                          items: ['employee', 'presidente'].map((r) => DropdownMenuItem(
                            value: r,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _roleColor(r).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                r.toUpperCase(),
                                style: TextStyle(color: _roleColor(r), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          )).toList(),
                          onChanged: (newRole) async {
                            if (newRole == null || newRole == user.role) return;
                            await _confirmRoleChange(context, user, newRole);
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'superadmin': return Colors.purple;
      case 'presidente': return Colors.teal;
      default: return Colors.blueGrey;
    }
  }

  Future<void> _confirmRoleChange(BuildContext context, UfficioUser user, String newRole) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Cambia Ruolo'),
        content: Text(
          'Vuoi cambiare il ruolo di ${user.displayName ?? user.email} da '
          '${user.role.toUpperCase()} a ${newRole.toUpperCase()}?'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annulla')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: Text('Conferma'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'role': newRole});
      // Log cambio ruolo
      await FirebaseFirestore.instance.collection('logs').add({
        'type': 'ROLE_CHANGE',
        'targetUserId': user.uid,
        'oldRole': user.role,
        'newRole': newRole,
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ruolo aggiornato!'), backgroundColor: Colors.teal),
      );
    }
  }
}
