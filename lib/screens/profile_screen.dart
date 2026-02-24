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

  // ── PALETTE AMPLIATA (40 colori) ──────────────────────────────────────────
  final List<Map<String, dynamic>> _colorPalette = [
    // Rossi / Rosa
    {'hex': '#FF1744', 'label': 'Rosso vivo'},
    {'hex': '#FF5252', 'label': 'Rosso'},
    {'hex': '#FF6B6B', 'label': 'Corallo'},
    {'hex': '#FF8A80', 'label': 'Salmone'},
    {'hex': '#F06292', 'label': 'Rosa'},
    {'hex': '#EC407A', 'label': 'Rosa scuro'},
    {'hex': '#E91E63', 'label': 'Fucsia'},
    // Viola / Indaco
    {'hex': '#CE93D8', 'label': 'Lavanda'},
    {'hex': '#AB47BC', 'label': 'Viola'},
    {'hex': '#9C27B0', 'label': 'Viola scuro'},
    {'hex': '#7C4DFF', 'label': 'Viola elettrico'},
    {'hex': '#673AB7', 'label': 'Indaco scuro'},
    {'hex': '#5C6BC0', 'label': 'Indaco'},
    // Blu
    {'hex': '#3F51B5', 'label': 'Blu navy'},
    {'hex': '#2196F3', 'label': 'Blu'},
    {'hex': '#03A9F4', 'label': 'Celeste'},
    {'hex': '#00BCD4', 'label': 'Ciano'},
    {'hex': '#45B7D1', 'label': 'Azzurro'},
    {'hex': '#0288D1', 'label': 'Blu oceano'},
    {'hex': '#01579B', 'label': 'Blu scuro'},
    // Verde
    {'hex': '#00BFA5', 'label': 'Teal vivo'},
    {'hex': '#009688', 'label': 'Teal'},
    {'hex': '#4ECDC4', 'label': 'Turchese'},
    {'hex': '#26A69A', 'label': 'Verde acqua'},
    {'hex': '#4CAF50', 'label': 'Verde'},
    {'hex': '#2ECC71', 'label': 'Verde lime'},
    {'hex': '#66BB6A', 'label': 'Verde mela'},
    {'hex': '#96CEB4', 'label': 'Verde menta'},
    {'hex': '#1B5E20', 'label': 'Verde bosco'},
    // Giallo / Arancio
    {'hex': '#FFEB3B', 'label': 'Giallo'},
    {'hex': '#FFC107', 'label': 'Ambra'},
    {'hex': '#FFEAA7', 'label': 'Giallo pastello'},
    {'hex': '#FF9800', 'label': 'Arancione'},
    {'hex': '#FF6D00', 'label': 'Arancione scuro'},
    {'hex': '#F39C12', 'label': 'Ocra'},
    // Neutri / Speciali
    {'hex': '#795548', 'label': 'Marrone'},
    {'hex': '#607D8B', 'label': 'Grigio ardesia'},
    {'hex': '#546E7A', 'label': 'Grigio blu'},
    {'hex': '#DDA0DD', 'label': 'Prugna'},
    {'hex': '#FF6F00', 'label': 'Miele'},
  ];

  String _selectedColor = '#4ECDC4';

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _nameController.text = auth.currentUser?.displayName ?? '';
    _tariffaController.text =
        (auth.currentUser?.tariffa ?? 50.0).toStringAsFixed(0);
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
        'displayName': _nameController.text.trim(),
        'personaColor': _selectedColor,
        'tariffa': double.tryParse(_tariffaController.text) ?? 50.0,
      });
      await auth.firebaseUser!.updateDisplayName(_nameController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profilo aggiornato!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final primary = Theme.of(context).colorScheme.primary;
    final avatarColor =
        Color(int.parse('FF${_selectedColor.replaceAll("#", "")}', radix: 16));

    return Scaffold(
      appBar: AppBar(
        title: Text('Il mio Profilo'),
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
                _nameController.text.isNotEmpty
                    ? _nameController.text[0].toUpperCase()
                    : 'U',
                style: TextStyle(
                    fontSize: 36,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 8),
            Text(user?.email ?? '',
                style: TextStyle(color: Colors.grey.shade600)),
            SizedBox(height: 6),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primary),
              ),
              child: Text(
                user?.role.toUpperCase() ?? '',
                style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
            SizedBox(height: 32),

            // NOME
            TextFormField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Nome visualizzato',
                prefixIcon: Icon(Icons.person),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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

            // GRIGLIA COLORI AMPLIATA
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colorPalette.map((item) {
                final c = item['hex'] as String;
                final col =
                    Color(int.parse('FF${c.replaceAll("#", "")}', radix: 16));
                final selected = _selectedColor == c;
                return Tooltip(
                  message: item['label'] as String,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 150),
                      width: selected ? 46 : 40,
                      height: selected ? 46 : 40,
                      decoration: BoxDecoration(
                        color: col,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: Colors.black87, width: 3)
                            : Border.all(color: Colors.transparent),
                        boxShadow: selected
                            ? [BoxShadow(color: col.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)]
                            : [],
                      ),
                      child: selected
                          ? Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
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
                icon: _loading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Icon(Icons.save),
                label:
                    Text('Salva Profilo', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
