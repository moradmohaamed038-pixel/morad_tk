/// main.dart
library;

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'screens/my_devices_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MoradTkApp());
}

class MoradTkApp extends StatelessWidget {
  const MoradTkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MORAD_TK',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
      home: const _AuthGate(),
    );
  }
}

/// بوابة المصادقة: تستمع لحالة تسجيل الدخول وتعرض الشاشة المناسبة تلقائياً.
/// لا حاجة لإدارة تنقّل يدوية بعد تسجيل الدخول/الخروج — هذا الودجت يتكفّل بها.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snapshot.data;
        return user == null ? const LoginScreen() : const MyDevicesScreen();
      },
    );
  }
}
