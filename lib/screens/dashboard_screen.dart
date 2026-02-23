import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ufficio App'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => auth.signOut(),
            tooltip: 'Logout',
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: Colors.teal),
            SizedBox(height: 16),
            Text('Benvenuto!',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(user?.displayName ?? user?.email ?? 'Utente',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.teal),
              ),
              child: Text(
                user?.role.toUpperCase() ?? 'EMPLOYEE',
                style: TextStyle(
                    color: Colors.teal, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 32),
            Text('Firebase Auth ✅ Firestore ✅',
                style: TextStyle(color: Colors.green)),
          ],
        ),
      ),
    );
  }
}
