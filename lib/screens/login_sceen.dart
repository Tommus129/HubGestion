import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMessage = null; });

    final authService = Provider.of<AuthService>(context, listen: false);
    final error = await authService.signIn(
      _emailController.text,
      _passwordController.text,
    );

    setState(() {
      _loading = false;
      _errorMessage = error;
    });
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // LOGO / TITOLO
                  Icon(Icons.business, size: 64, color: Colors.teal),
                  SizedBox(height: 8),
                  Text('Ufficio App',
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold)),
                  Text('Accedi al tuo account',
                      style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 32),

                  // EMAIL
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    validator: (v) =>
                        v!.isEmpty ? 'Inserisci email' : null,
                  ),
                  SizedBox(height: 16),

                  // PASSWORD
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    validator: (v) =>
                        v!.isEmpty ? 'Inserisci password' : null,
                    onFieldSubmitted: (_) => _login(),
                  ),
                  SizedBox(height: 16),

                  // ERRORE
                  if (_errorMessage != null)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                              child: Text(_errorMessage!,
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ),
                  if (_errorMessage != null) SizedBox(height: 16),

                  // BOTTONE LOGIN
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _loading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text('Accedi',
                              style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  SizedBox(height: 16),

                  // LINK REGISTRAZIONE
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => RegisterScreen()),
                    ),
                    child: Text("Non hai un account? Registrati",
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
