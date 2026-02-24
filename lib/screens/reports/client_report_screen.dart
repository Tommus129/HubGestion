import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';

class ClientReportScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Report Cliente'), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      drawer: AppDrawer(),
      body: Center(child: Text('Report - Coming Soon', style: TextStyle(fontSize: 18, color: Colors.grey))),
    );
  }
}
