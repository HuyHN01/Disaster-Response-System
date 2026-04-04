// lib/features/event_map/domain/event_map_controller.dart

import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/features/rescue_stations/domain/rescue_station_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Active rescue stations stream for citizen map rendering.
final rescueStationsProvider = StreamProvider<List<RescueStation>>((ref) {
  final repo = ref.watch(rescueStationRepositoryProvider);
  return repo.watchActiveStations();
});
