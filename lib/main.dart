import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/calendar_screen.dart';
import 'utils/app_theme.dart';
// import 'utils/seed_data.dart'; // ← decommentare per il seed, poi ricommentare

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ⬇️ SEED: decommentare UNA VOLTA SOLA per popolare Firestore, poi ricommentare
  // await seedFirestore();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: UfficioApp(),
    ),
  );
}

class UfficioApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        Color primaryColor = Colors.teal;
        if (auth.currentUser?.personaColor != null) {
          final hex = auth.currentUser!.personaColor!.replaceAll('#', '');
          primaryColor = Color(int.parse('FF$hex', radix: 16));
        }

        return MaterialApp(
          title: 'StepNet',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(primaryColor),
          home: auth.isLoggedIn ? CalendarScreen() : LoginScreen(),
        );
      },
    );
  }
}
