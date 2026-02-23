import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMessage = null; });

    final authService = Provider.of<AuthService>(context, listen: false);
    final error = await authService.register(
      _emailController.text,
      _passwordController.text,
      _nameController.text,
    );

    if (error != null) {
      setState(() { _loading = false; _errorMessage = error; });
    }
    // Se null = successo, AuthWrapper fa redirect automatico
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400,
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16)],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add, size: 64, color: Colors.teal),
                  SizedBox(height: 8),
                  Text('Registrati',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  SizedBox(height: 32),

                  // NOME
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nome completo',
                      prefixIcon: Icon(Icons.person_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    validator: (v) => v!.isEmpty ? 'Inserisci il tuo nome' : null,
                  ),
                  SizedBox(height: 16),

                  // EMAIL
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    validator: (v) => v!.isEmpty ? 'Inserisci email' : null,
                  ),
                  SizedBox(height: 16),

                  // PASSWORD
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password (min. 6 caratteri)',
                      prefixIcon: Icon(Icons.lock_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    validator: (v) =>
                        v!.length < 6 ? 'Min. 6 caratteri' : null,
                  ),
                  SizedBox(height: 16),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(_errorMessage!,
                          style: TextStyle(color: Colors.red)),
                    ),
                    SizedBox(height: 16),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _loading
                          ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : Text('Registrati', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  SizedBox(height: 16),

                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Hai già un account? Accedi',
                        style: TextStyle(color: Colors.teal)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
