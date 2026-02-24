import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';

class UsersRolesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Gestione Utenti'), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      drawer: AppDrawer(),
      body: Center(child: Text('Gestione Ruoli - Coming Soon', style: TextStyle(fontSize: 18, color: Colors.grey))),
    );
  }
}
