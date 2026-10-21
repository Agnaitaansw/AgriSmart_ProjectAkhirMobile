import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'services/auth_service.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //inisialisasi koneksi PostgreSQL Supabase
  await Supabase.initialize(
    url: 'https://zjhvszksxuobfaxolthf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpqaHZzemtzeHVvYmZheG9sdGhmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI1NTg3NzEsImV4cCI6MjEwODEzNDc3MX0.HG5qhxyCHHXTvQ3oiAgbQt8Ra99sGrV7pade5gq4LAI',
  );
  // Cek session tersimpan: kalau masih valid, langsung ke Home.
  final loggedIn = await AuthService.instance.hasValidSession();
  runApp(AgriSmartApp(startLoggedIn: loggedIn));
}

class AgriSmartApp extends StatelessWidget {
  final bool startLoggedIn;
  const AgriSmartApp({super.key, required this.startLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriSmart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: startLoggedIn ? const BerandaScreen() : const LoginPage(),
    );
  }
}
