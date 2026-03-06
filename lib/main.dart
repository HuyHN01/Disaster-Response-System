import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// TODO: Import Firebase & Drift setup later

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // TODO: Initialize Firebase
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
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
      home: const Scaffold(
        body: Center(
          child: Text(
            'VibeCode Master: Foundation Setup Complete! 🚀\nSẵn sàng code chức năng.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}