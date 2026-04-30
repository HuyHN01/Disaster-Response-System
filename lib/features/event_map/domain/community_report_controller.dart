import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/core/database/db_provider.dart';
import 'package:disaster_response_app/core/services/firebase/sync_service.dart';
import 'package:drift/drift.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<void> deleteReport(String reportId) async {
    final db = _ref.read(dbProvider);
    
    try {
      // Xóa trên Firestore trước
      await FirebaseFirestore.instance
          .collection('community_reports')
          .doc(reportId)
          .delete();
    } catch (e) {
      // Xử lý lỗi nếu cần thiết
    }

    // Xóa dưới local Drift
    await (db.delete(db.communityReports)..where((r) => r.id.equals(reportId))).go();
  }

  Future<void> updateReport({
    required String reportId,
    required String type,
    String? customTypeName,
    String? description,
  }) async {
    final db = _ref.read(dbProvider);
    
    final companion = CommunityReportsCompanion(
      type: Value(type),
      description: Value(description),
      customTypeName: Value(customTypeName),
      syncStatus: const Value('pending'),
    );

    await (db.update(db.communityReports)..where((r) => r.id.equals(reportId))).write(companion);

    // Bắt đầu đồng bộ lên cloud
    final syncService = _ref.read(firebaseSyncServiceProvider);
    await syncService.syncPendingCommunityReports();
  }
}
