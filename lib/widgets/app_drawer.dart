import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../screens/calendar_screen.dart';
import '../screens/clients/clients_list_screen.dart';
import '../screens/reports/client_report_screen.dart';
import '../screens/admin/rooms_screen.dart';
import '../screens/admin/users_roles_screen.dart';

class AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;

    // FIX: stringa sicura per avatar
    final displayName = user?.displayName ?? user?.email ?? 'Utente';
    final avatarLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.teal),
            accountName: Text(displayName),
            accountEmail: Text(user?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                avatarLetter,
                style: TextStyle(color: Colors.teal, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          ListTile(
            leading: Icon(Icons.calendar_month, color: Colors.teal),
            title: Text('Calendario'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CalendarScreen()));
            },
          ),

          ListTile(
            leading: Icon(Icons.people, color: Colors.teal),
            title: Text('Clienti'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ClientsListScreen()));
            },
          ),

          ListTile(
            leading: Icon(Icons.bar_chart, color: Colors.teal),
            title: Text('Report Cliente'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ClientReportScreen()));
            },
          ),

          if (user?.isAdmin == true) ...[
            Divider(),
            Padding(
              padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
              child: Text('AMMINISTRAZIONE',
                  style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: Icon(Icons.meeting_room, color: Colors.teal),
              title: Text('Stanze'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RoomsScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.manage_accounts, color: Colors.teal),
              title: Text('Gestione Utenti'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UsersRolesScreen()));
              },
            ),
          ],

          Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () => auth.signOut(),
          ),
        ],
      ),
    );
  }
}
