import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../widgets/app_drawer.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _tariffaController = TextEditingController();
  bool _loading = false;

  final List<String> _colors = [
    '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4',
    '#FFEAA7', '#DDA0DD', '#F39C12', '#2ECC71',
    '#E74C3C', '#9B59B6', '#3498DB', '#1ABC9C',
  ];
  String _selectedColor = '#4ECDC4';

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _nameController.text = auth.currentUser?.displayName ?? '';
    _tariffaController.text = '50';
    _selectedColor = auth.currentUser?.personaColor ?? '#4ECDC4';
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.firebaseUser!.uid)
          .update({
        'displayName': _nameController.text,
        'personaColor': _selectedColor,
        'tariffa': double.tryParse(_tariffaController.text) ?? 50.0,
      });
      await auth.firebaseUser!.updateDisplayName(_nameController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profilo aggiornato!'), backgroundColor: Colors.teal),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
      );
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final avatarColor = Color(int.parse('FF${_selectedColor.replaceAll("#", "")}', radix: 16));

    return Scaffold(
      appBar: AppBar(
        title: Text('Il mio Profilo'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      drawer: AppDrawer(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            // AVATAR PREVIEW
            CircleAvatar(
              radius: 48,
              backgroundColor: avatarColor,
              child: Text(
                _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'U',
                style: TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 8),
            Text(user?.email ?? '', style: TextStyle(color: Colors.grey)),
            Container(
              margin: EdgeInsets.only(top: 6),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.teal),
              ),
              child: Text(user?.role.toUpperCase() ?? '',
                  style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            SizedBox(height: 32),

            // NOME
            TextFormField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Nome visualizzato',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            SizedBox(height: 16),

            // TARIFFA DEFAULT
            TextFormField(
              controller: _tariffaController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Tariffa default (€/ora)',
                prefixIcon: Icon(Icons.euro),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            SizedBox(height: 24),

            // COLORE PERSONA
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Colore nel calendario',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colors.map((c) {
                final col = Color(int.parse('FF${c.replaceAll("#", "")}', radix: 16));
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: col,
                      shape: BoxShape.circle,
                      border: _selectedColor == c
                          ? Border.all(color: Colors.black, width: 3)
                          : Border.all(color: Colors.transparent),
                      boxShadow: _selectedColor == c
                          ? [BoxShadow(color: col.withOpacity(0.5), blurRadius: 8)]
                          : [],
                    ),
                    child: _selectedColor == c
                        ? Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 32),

            // SALVA
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _loading
                    ? SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(Icons.save),
                label: Text('Salva Profilo', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
