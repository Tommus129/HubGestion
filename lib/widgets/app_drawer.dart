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
import '../screens/profile_screen.dart';

class AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName! : user?.email ?? 'Utente';
    final avatarLetter = displayName.isNotEmpty
        ? displayName[0].toUpperCase() : 'U';

    return Drawer(
      child: Column(
        children: [
          // HEADER con colore tema
          InkWell(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ProfileScreen()));
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16, 48, 16, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primary,
                    primary.withOpacity(0.75),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(avatarLetter, style: TextStyle(
                      color: Colors.white, fontSize: 26,
                      fontWeight: FontWeight.bold,
                    )),
                  ),
                  SizedBox(height: 12),
                  Row(children: [
                    Text(displayName, style: TextStyle(
                      color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.bold,
                    )),
                    SizedBox(width: 6),
                    Icon(Icons.edit, size: 14, color: Colors.white60),
                  ]),
                  SizedBox(height: 2),
                  Text(user?.email ?? '', style: TextStyle(
                    color: Colors.white70, fontSize: 12,
                  )),
                  SizedBox(height: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Text(
                      user?.role.toUpperCase() ?? '',
                      style: TextStyle(color: Colors.white,
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // MENU ITEMS
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: 8),
              children: [
                _item(context, Icons.calendar_month, 'Calendario', primary, () =>
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => CalendarScreen()))),

                _item(context, Icons.people, 'Clienti', primary, () =>
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => ClientsListScreen()))),

                _sectionLabel('REPORT', primary),

                _item(context, Icons.person_search, 'Report Cliente', primary, () =>
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => ClientReportScreen()))),

                _item(context, Icons.euro, 'Report Pagamenti', primary, () =>
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => PaymentsReportScreen()))),

                if (user?.isAdmin == true) ...[
                  _sectionLabel('AMMINISTRAZIONE', primary),
                  _item(context, Icons.meeting_room, 'Stanze', primary, () =>
                      Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (_) => RoomsScreen()))),
                  _item(context, Icons.manage_accounts, 'Gestione Utenti', primary, () =>
                      Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (_) => UsersRolesScreen()))),
                  _item(context, Icons.shield, 'Log Sicurezza', primary, () =>
                      Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (_) => LogsScreen()))),
                ],
              ],
            ),
          ),

          // LOGOUT in fondo
          Divider(height: 1),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
            onTap: () => auth.signOut(),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _item(BuildContext ctx, IconData icon, String title,
      Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
      onTap: () { Navigator.pop(ctx); onTap(); },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      horizontalTitleGap: 8,
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label, style: TextStyle(
        fontSize: 11, color: color,
        fontWeight: FontWeight.bold, letterSpacing: 1.2,
      )),
    );
  }
}
