import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../screens/calendar_screen.dart';
import '../screens/clients/clients_list_screen.dart';
import '../screens/reports/payments_report_screen.dart';
import '../screens/reports/client_report_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/admin/users_roles_screen.dart';
import '../screens/admin/logs_screen.dart';

class AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final primary = Theme.of(context).colorScheme.primary;
    final isAdmin = user?.isAdmin ?? false;

    // Colore avatar dal profilo utente
    Color avatarColor = primary;
    if (user?.personaColor != null) {
      try {
        avatarColor = Color(int.parse(
            'FF${user!.personaColor!.replaceAll("#", "")}',
            radix: 16));
      } catch (_) {}
    }

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: avatarColor,
                  child: Text(
                    (user?.displayName ?? user?.email ?? 'U').isNotEmpty
                        ? (user?.displayName ?? user?.email ?? 'U')[0].toUpperCase()
                        : 'U',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  user?.displayName ?? user?.email ?? '',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (user?.email != null)
                  Text(user!.email, style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),

          // ── PRINCIPALE ────────────────────────────────────────────────
          ListTile(
            leading: Icon(Icons.calendar_month, color: primary),
            title: Text('Calendario'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CalendarScreen()));
            },
          ),

          ListTile(
            leading: Icon(Icons.people, color: primary),
            title: Text('Clienti'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ClientsListScreen()));
            },
          ),

          // ── REPORT ────────────────────────────────────────────────────
          Divider(),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text('Report', style: TextStyle(
                fontSize: 11, color: Colors.grey[500],
                fontWeight: FontWeight.w600, letterSpacing: 0.8)),
          ),

          ListTile(
            leading: Icon(Icons.euro, color: Colors.green[600]),
            title: Text('Pagamenti'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PaymentsReportScreen()));
            },
          ),

          ListTile(
            leading: Icon(Icons.bar_chart, color: Colors.blue[600]),
            title: Text('Report Cliente'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ClientReportScreen()));
            },
          ),

          // ── ADMIN (solo se isAdmin) ───────────────────────────────────
          if (isAdmin) ...[
            Divider(),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text('Amministrazione', style: TextStyle(
                  fontSize: 11, color: Colors.grey[500],
                  fontWeight: FontWeight.w600, letterSpacing: 0.8)),
            ),
            ListTile(
              leading: Icon(Icons.manage_accounts, color: Colors.orange[700]),
              title: Text('Gestione Ruoli'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UsersRolesScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.bug_report, color: Colors.red[400]),
              title: Text('Log Debug'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LogsScreen()));
              },
            ),
          ],

          // ── PROFILO / LOGOUT ─────────────────────────────────────────
          Divider(),

          ListTile(
            leading: Icon(Icons.person_outline, color: primary),
            title: Text('Profilo'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProfileScreen()));
            },
          ),

          ListTile(
            leading: Icon(Icons.logout, color: Colors.red[400]),
            title: Text('Logout', style: TextStyle(color: Colors.red[400])),
            onTap: () async {
              Navigator.pop(context);
              await auth.signOut();
            },
          ),
        ],
      ),
    );
  }
}
