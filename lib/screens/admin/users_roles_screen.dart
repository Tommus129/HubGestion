import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_drawer.dart';

class UsersRolesScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Una palette di colori belli ed eleganti tra cui scegliere
  final List<Color> _availableColors = [
    Colors.red.shade400,
    Colors.pink.shade400,
    Colors.purple.shade400,
    Colors.deepPurple.shade400,
    Colors.indigo.shade400,
    Colors.blue.shade400,
    Colors.lightBlue.shade400,
    Colors.cyan.shade400,
    Colors.teal.shade400,
    Colors.green.shade400,
    Colors.lightGreen.shade400,
    Colors.orange.shade400,
    Colors.deepOrange.shade400,
    Colors.brown.shade400,
    Colors.blueGrey.shade400,
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final auth = Provider.of<AuthService>(context);
    final currentUser = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text('Gestione Utenti')),
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
              final isSuperAdmin = currentUser?.role == 'superadmin';

              // Colore utente (salvato o hash)
              Color userColor;
              if (user.personaColor != null && user.personaColor!.isNotEmpty) {
                try {
                  userColor = Color(int.parse('FF${user.personaColor!.replaceAll('#', '')}', radix: 16));
                } catch (_) {
                  userColor = _generateUserColor(user.uid);
                }
              } else {
                userColor = _generateUserColor(user.uid);
              }

              return Card(
                margin: EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Avatar cliccabile per cambiare colore (se admin o se stessi)
                      GestureDetector(
                        onTap: isSuperAdmin ? () => _changeUserColor(context, user) : null,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              backgroundColor: userColor,
                              radius: 24,
                              child: Text(
                                (user.displayName ?? user.email).isNotEmpty ? (user.displayName ?? user.email)[0].toUpperCase() : 'U',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                              ),
                            ),
                            if (isSuperAdmin)
                              Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey.shade300)
                                ),
                                child: Icon(Icons.palette, size: 12, color: Colors.black87),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(user.displayName ?? 'Senza nome', style: TextStyle(fontWeight: FontWeight.bold)),
                              if (isCurrentUser) ...[
                                SizedBox(width: 6),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                  child: Text('Tu', style: TextStyle(fontSize: 10, color: primary)),
                                ),
                              ],
                            ]),
                            Text(user.email, style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      
                      // Gestione Ruolo
                      if (user.role == 'superadmin' || !isSuperAdmin)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _roleColor(user.role, primary).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _roleColor(user.role, primary).withOpacity(0.4)),
                          ),
                          child: Text(user.role.toUpperCase(), style: TextStyle(color: _roleColor(user.role, primary), fontWeight: FontWeight.bold, fontSize: 12)),
                        )
                      else
                        DropdownButton<String>(
                          value: user.role,
                          underline: SizedBox(),
                          items: ['employee', 'presidente'].map((r) => DropdownMenuItem(
                            value: r,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: _roleColor(r, primary).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                              child: Text(r.toUpperCase(), style: TextStyle(color: _roleColor(r, primary), fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          )).toList(),
                          onChanged: (newRole) async {
                            if (newRole == null || newRole == user.role) return;
                            await _confirmRoleChange(context, user, newRole, primary);
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

  Color _roleColor(String role, Color primary) {
    switch (role) {
      case 'superadmin': return Colors.purple;
      case 'presidente': return primary;
      default: return Colors.blueGrey;
    }
  }

  Color _generateUserColor(String uid) {
    final hash = uid.hashCode;
    final r = (hash & 0xFF0000) >> 16;
    final g = (hash & 0x00FF00) >> 8;
    final b = (hash & 0x0000FF);
    return Color.fromARGB(255, r, g, b).withOpacity(1.0);
  }

  // Dialog per cambiare colore
  Future<void> _changeUserColor(BuildContext context, UfficioUser user) async {
    final selectedColor = await showDialog<Color>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Scegli il colore di ${user.displayName ?? "questo utente"}'),
          content: Container(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: _availableColors.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final color = _availableColors[index];
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(color),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: Text('Annulla'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      }
    );

    if (selectedColor != null) {
      // Salva come stringa HEX
      final hex = selectedColor.value.toRadixString(16).substring(2).toUpperCase();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'personaColor': '#$hex',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Colore aggiornato con successo!')),
      );
    }
  }

  Future<void> _confirmRoleChange(BuildContext context, UfficioUser user, String newRole, Color primary) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Cambia Ruolo'),
        content: Text('Vuoi cambiare il ruolo di ${user.displayName ?? user.email} da ${user.role.toUpperCase()} a ${newRole.toUpperCase()}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annulla')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
            child: Text('Conferma'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'role': newRole});
      await FirebaseFirestore.instance.collection('logs').add({
        'type': 'ROLE_CHANGE',
        'targetUserId': user.uid,
        'oldRole': user.role,
        'newRole': newRole,
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ruolo aggiornato!'), backgroundColor: primary),
      );
    }
  }
}
