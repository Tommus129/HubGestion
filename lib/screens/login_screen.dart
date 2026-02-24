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

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMessage = null; });
    final auth = Provider.of<AuthService>(context, listen: false);
    final error = await auth.signIn(_emailController.text, _passwordController.text);
    setState(() { _loading = false; _errorMessage = error; });
  }

  @override
  Widget build(BuildContext context) {
    // Nella login il tema non è ancora caricato (nessun utente loggato),
    // usiamo teal come colore di fallback solo qui
    const brandColor = Colors.teal;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
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
                Icon(Icons.business, size: 64, color: brandColor),
                SizedBox(height: 8),
                Text('StepNet',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                Text('Accedi al tuo account',
                    style: TextStyle(color: Colors.grey)),
                SizedBox(height: 32),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (v) => v!.isEmpty ? 'Inserisci email' : null,
                ),
                SizedBox(height: 16),

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
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (v) => v!.isEmpty ? 'Inserisci password' : null,
                  onFieldSubmitted: (_) => _login(),
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
                    child: Row(children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text(_errorMessage!,
                              style: TextStyle(color: Colors.red))),
                    ]),
                  ),
                  SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
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
                        : Text('Accedi', style: TextStyle(fontSize: 16)),
                  ),
                ),
                SizedBox(height: 16),

                TextButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => RegisterScreen())),
                  style: TextButton.styleFrom(foregroundColor: brandColor),
                  child: Text('Non hai un account? Registrati'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
