import 'package:disaster_response_app/core/routes/app_router.dart';
import 'package:disaster_response_app/core/services/firebase/fcm_service.dart';
import 'package:disaster_response_app/core/services/firebase/sync_service.dart';
import 'package:disaster_response_app/features/admin_panel/domain/event_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// TODO: Import Firebase & Drift setup later

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Khởi tạo FCM — PHẢI sau Firebase.initializeApp()
  await FCMService.instance.initialize();


  // Load environment variables
  await dotenv.load(fileName: ".env");
  final SUPABASE_URL = dotenv.get('SUPABASE_URL');
  final SUPABASE_ANON_KEY = dotenv.get('SUPABASE_ANON_KEY');

  // TODO: Initialize Supabase
  await Supabase.initialize(
    url: SUPABASE_URL,
    anonKey: SUPABASE_ANON_KEY,
  );

  // TODO: Initialize Drift Database

  runApp(const ProviderScope(child: OmniDisasterApp()));
}

class OmniDisasterApp extends ConsumerWidget {
  const OmniDisasterApp({super.key});

  // GoRouter instance — created once and reused for the lifetime of the app.
  static final _router = AppRouter.createRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    ref.read(firebaseSyncServiceProvider).listenToAdminEvents(
      onNewEvent: (event) => ref.invalidate(eventControllerProvider),
    );

    return MaterialApp.router(
      routerConfig: _router,
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      supportedLocales: FlutterQuillLocalizations.supportedLocales,
      title: 'Hệ thống Ứng phó Thiên tai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.redAccent,
        textTheme: GoogleFonts.interTextTheme(),
      ),
    );
  }
}

