import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/core/database/db_provider.dart';
import 'package:disaster_response_app/core/services/firebase/sync_service.dart';
import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final communityReportsProvider = StreamProvider<List<CommunityReport>>((ref) {
  final db = ref.watch(dbProvider);
  return db.select(db.communityReports).watch();
});

final communityReportControllerProvider = Provider<CommunityReportController>((ref) {
  return CommunityReportController(ref);
});

class CommunityReportController {
  final Ref _ref;
  final _uuid = const Uuid();

  CommunityReportController(this._ref);

  Future<void> addReport({
    required double latitude,
    required double longitude,
    required String type,
    String? customTypeName,
    String? description,
  }) async {
    final db = _ref.read(dbProvider);
    final user = FirebaseAuth.instance.currentUser;
    final reporterId = user?.uid ?? 'anonymous';

    final reportId = _uuid.v4();

    final companion = CommunityReportsCompanion.insert(
      id: reportId,
      type: type,
      latitude: latitude,
      longitude: longitude,
      description: Value(description),
      customTypeName: Value(customTypeName),
      reportedBy: reporterId,
      createdAt: DateTime.now(),
      syncStatus: const Value('pending'),
    );

    await db.into(db.communityReports).insert(companion);

    // Bắt đầu đồng bộ lên cloud
    final syncService = _ref.read(firebaseSyncServiceProvider);
    await syncService.syncPendingCommunityReports();
  }
}
