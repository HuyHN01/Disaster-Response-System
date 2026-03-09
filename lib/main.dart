import 'package:disaster_response_app/core/services/firebase/sync_service.dart';
import 'package:disaster_response_app/features/admin_panel/domain/event_controller.dart';
import 'package:disaster_response_app/features/admin_panel/presentation/admin_map_screen.dart';
import 'package:disaster_response_app/features/admin_panel/presentation/event_dashboard_screen.dart';
import 'package:disaster_response_app/features/user_mobile/presentation/mobile_home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
// TODO: Import Firebase & Drift setup later

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");
  // TODO: Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // TODO: Initialize Drift Database

  runApp(const ProviderScope(child: OmniDisasterApp()));
}

class OmniDisasterApp extends ConsumerWidget {
  const OmniDisasterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    
    ref.read(firebaseSyncServiceProvider).listenToAdminEvents(
      onNewEvent: (event) => ref.invalidate(eventControllerProvider),
    );

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
