import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../screens/calendar_screen.dart';
import '../screens/clients/clients_list_screen.dart';
import '../screens/reports/client_report_screen.dart';
import '../screens/reports/payments_report_screen.dart';
import '../screens/admin/rooms_screen.dart';
import '../screens/admin/users_roles_screen.dart';
import '../screens/admin/logs_screen.dart';

class AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
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
              child: Text(avatarLetter,
                  style: TextStyle(color: Colors.teal, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
          ),

          _drawerItem(context, Icons.calendar_month, 'Calendario', () =>
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CalendarScreen()))),

          _drawerItem(context, Icons.people, 'Clienti', () =>
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ClientsListScreen()))),

          Divider(),
          _sectionLabel('REPORT'),

          _drawerItem(context, Icons.person_search, 'Report Cliente', () =>
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ClientReportScreen()))),

          _drawerItem(context, Icons.euro, 'Report Pagamenti', () =>
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PaymentsReportScreen()))),

          if (user?.isAdmin == true) ...[
            Divider(),
            _sectionLabel('AMMINISTRAZIONE'),

            _drawerItem(context, Icons.meeting_room, 'Stanze', () =>
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RoomsScreen()))),

            _drawerItem(context, Icons.manage_accounts, 'Gestione Utenti', () =>
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UsersRolesScreen()))),

            _drawerItem(context, Icons.shield, 'Log Sicurezza', () =>
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LogsScreen()))),
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

  Widget _drawerItem(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.teal),
      title: Text(title),
      onTap: () { Navigator.pop(context); onTap(); },
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(left: 16, top: 4, bottom: 4),
      child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
    );
  }
}
