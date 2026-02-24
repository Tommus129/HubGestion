import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';

class RoomsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Stanze'), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      drawer: AppDrawer(),
      body: Center(child: Text('Gestione Stanze - Coming Soon', style: TextStyle(fontSize: 18, color: Colors.grey))),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.teal,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
