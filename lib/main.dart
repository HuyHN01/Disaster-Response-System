import 'dart:async';

import 'package:disaster_response_app/core/routes/app_router.dart';
import 'package:disaster_response_app/core/services/firebase/fcm_service.dart';
import 'package:disaster_response_app/core/services/firebase/sync_service.dart';
import 'package:disaster_response_app/features/admin_panel/domain/event_controller.dart';
import 'package:disaster_response_app/features/admin_panel/rescue_stations/domain/rescue_station_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// TODO: Import Firebase & Drift setup later

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Load environment variables
  await dotenv.load(fileName: ".env");
  final supabaseUrl = dotenv.get('SUPABASE_URL');
  final supabaseAnonKey = dotenv.get('SUPABASE_ANON_KEY');

  // TODO: Initialize Supabase
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  // TODO: Initialize Drift Database

  final router = AppRouter.createRouter();
  FCMService.instance.attachRouter(router);

  runApp(ProviderScope(child: OmniDisasterApp(router: router)));

  // Khởi tạo FCM nền để không chặn render màn hình đầu tiên.
  unawaited(
    FCMService.instance.initialize().catchError((error, stackTrace) {
      debugPrint('[main] FCM init lỗi (không chặn app): $error');
    }),
  );
}

class OmniDisasterApp extends ConsumerWidget {
  final GoRouter router;

  const OmniDisasterApp({super.key, required this.router});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncService = ref.read(firebaseSyncServiceProvider);

    syncService.listenToAdminEvents(
      onNewEvent: (event) => ref.invalidate(eventControllerProvider),
    );
    syncService.listenToRescueStations(
      onUpsert: (_) => ref.invalidate(rescueStationControllerProvider),
    );
    syncService.listenToCommunityReports();
    syncService.listenToUsers();

    return MaterialApp.router(
      routerConfig: router,
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
