import 'package:disaster_response_app/features/admin_panel/presentation/event_dashboard_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
// TODO: Import Firebase & Drift setup later

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // TODO: Initialize Drift Database

  runApp(const ProviderScope(child: OmniDisasterApp()));
}

class OmniDisasterApp extends StatelessWidget {
  const OmniDisasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hệ thống Ứng phó Thiên tai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.redAccent, // Vibe khẩn cấp, cảnh báo
        textTheme: GoogleFonts.interTextTheme(), // Font chữ dễ đọc
      ),
      home: EventDashboardScreen(),
    );
  }
}
