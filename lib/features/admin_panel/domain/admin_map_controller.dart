// lib/features/admin_panel/domain/admin_map_controller.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// =============================================================================
// MODEL
// =============================================================================
class SosMapMarker {
  final String postId;
  final String content;
  final DateTime createdAt;
  final double latitude;
  final double longitude;

  const SosMapMarker({
    required this.postId,
    required this.content,
    required this.createdAt,
    required this.latitude,
    required this.longitude,
  });

  @override
  String toString() =>
      'SosMapMarker(id: $postId, lat: $latitude, lng: $longitude)';
}

// =============================================================================
// CONTROLLER
// =============================================================================

/// Lắng nghe collection `posts` (chỉ lọc `postType == 'sos'` trên Firestore
/// để tránh cần Composite Index), sau đó lọc/sort local bằng Dart thuần,
/// rồi fetch `locations` một lần để join tọa độ.
///
/// Không dùng `.where('isVerified', ...)` + `.orderBy(...)` cùng nhau
/// vì Firestore yêu cầu Index phức tạp và là nguồn gốc gây re-trigger loop.
class AdminMapController extends StreamNotifier<List<SosMapMarker>> {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  Stream<List<SosMapMarker>> build() {
    // ── Chỉ filter 1 field đơn giản — không cần Composite Index ─────────────
    final postsQuery = _db
        .collection('posts')
        .where('postType', isEqualTo: 'sos');

    return postsQuery.snapshots().asyncMap(_processSnapshot);
  }

  // ---------------------------------------------------------------------------
  // CORE JOIN LOGIC
  // ---------------------------------------------------------------------------

  Future<List<SosMapMarker>> _processSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    if (snapshot.docs.isEmpty) return [];

    // ── 1. Lọc & sort local (không cần Firebase Index) ─────────────────────
    final unverifiedDocs = snapshot.docs
        .where((d) => d.data()['isVerified'] != true)
        .toList()
      ..sort((a, b) {
        final aTs = a.data()['createdAt'];
        final bTs = b.data()['createdAt'];
        final aDate = aTs is Timestamp ? aTs.toDate() : DateTime(0);
        final bDate = bTs is Timestamp ? bTs.toDate() : DateTime(0);
        return bDate.compareTo(aDate); // mới nhất lên trước
      });

    if (unverifiedDocs.isEmpty) return [];

    // ── 2. Fetch locations (batch ≤ 30 theo giới hạn Firestore whereIn) ────
    final postIds = unverifiedDocs.map((d) => d.id).toList();
    final locationMap = await _fetchLocationsMap(postIds);

    // ── 3. Join → SosMapMarker ───────────────────────────────────────────────
    final markers = <SosMapMarker>[];
    for (final doc in unverifiedDocs) {
      try {
        final loc = locationMap[doc.id];
        if (loc == null) continue; // chưa có tọa độ — bỏ qua

        final data = doc.data();
        final rawTs = data['createdAt'];
        final createdAt =
            rawTs is Timestamp ? rawTs.toDate() : DateTime.now();

        markers.add(SosMapMarker(
          postId: doc.id,
          content:
              (data['content'] as String?) ?? '(Không có nội dung)',
          createdAt: createdAt,
          latitude: (loc['latitude'] as num).toDouble(),
          longitude: (loc['longitude'] as num).toDouble(),
        ));
      } catch (e) {
        // Bỏ qua document lỗi schema, không crash toàn bộ stream
        _log('Parse error cho post ${doc.id}: $e');
      }
    }

    // Log chỉ 1 lần mỗi khi có thay đổi thực sự
    _log('Updated: ${markers.length} SOS markers on map');
    return markers;
  }

  /// Fetch locations theo batch ≤ 30, trả về Map<postId, locationData>.
  Future<Map<String, Map<String, dynamic>>> _fetchLocationsMap(
    List<String> postIds,
  ) async {
    const batchSize = 30;
    final result = <String, Map<String, dynamic>>{};

    for (var i = 0; i < postIds.length; i += batchSize) {
      final batch = postIds.sublist(
        i,
        (i + batchSize).clamp(0, postIds.length),
      );
      try {
        final snap = await _db
            .collection('locations')
            .where('postId', whereIn: batch)
            .get();

        for (final doc in snap.docs) {
          final postId = doc.data()['postId'] as String?;
          if (postId != null) result[postId] = doc.data();
        }
      } catch (e) {
        _log('Fetch locations batch error (offset $i): $e');
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // PUBLIC ACTIONS
  // ---------------------------------------------------------------------------

  /// Đánh dấu SOS đã xử lý → stream tự cập nhật, marker tự biến mất.
  Future<void> markSosAsVerified(String postId) async {
    await _db.collection('posts').doc(postId).update({
      'isVerified': true,
      'verifiedAt': FieldValue.serverTimestamp(),
    });
    _log('✅ Post $postId marked as verified');
  }

  // ignore: avoid_print
  void _log(String msg) => print('[AdminMapCtrl] $msg');
}

// =============================================================================
// PROVIDERS
// =============================================================================

final adminMapProvider =
    StreamNotifierProvider<AdminMapController, List<SosMapMarker>>(
  AdminMapController.new,
);

/// Badge count cho sidebar — derived, không gây re-render map.
final unverifiedSosOnMapCountProvider = Provider<int>((ref) {
  return ref.watch(adminMapProvider).maybeWhen(
        data: (m) => m.length,
        orElse: () => 0,
      );
});