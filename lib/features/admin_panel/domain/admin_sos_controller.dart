// lib/features/admin_panel/domain/admin_sos_controller.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// =============================================================================
// SOS POST MODEL
// A lightweight model – no Drift dependency needed here since this data
// comes straight from Firestore and is only consumed by the Admin UI.
// =============================================================================
class SosPost {
  final String id;
  final String userId;
  final String eventId;
  final String content;
  final String syncStatus;
  final bool isVerified;
  final DateTime createdAt;

  const SosPost({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.content,
    required this.syncStatus,
    required this.isVerified,
    required this.createdAt,
  });

  /// Deserialise a Firestore document snapshot into [SosPost].
  factory SosPost.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawCreatedAt = data['createdAt'];

    return SosPost(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      eventId: (data['eventId'] as String?) ?? '',
      content: (data['content'] as String?) ?? '',
      syncStatus: (data['syncStatus'] as String?) ?? 'synced',
      isVerified: (data['isVerified'] as bool?) ?? false,
      createdAt: rawCreatedAt is Timestamp
          ? rawCreatedAt.toDate()
          : DateTime.now(),
    );
  }

  @override
  String toString() => 'SosPost(id: $id, userId: $userId, '
      'syncStatus: $syncStatus, createdAt: $createdAt)';
}

// =============================================================================
// CONTROLLER
// Uses [StreamNotifier] so Riverpod manages the subscription lifecycle
// automatically — no manual cancel() needed.
// =============================================================================
class AdminSosController extends StreamNotifier<List<SosPost>> {
  @override
  Stream<List<SosPost>> build() {
    final firestore = FirebaseFirestore.instance;

    // Listen to all SOS posts, ordered newest-first.
    // The Admin Panel may want to filter further (e.g. only unverified)
    // — add `.where('isVerified', isEqualTo: false)` if needed.
    final query = firestore
        .collection('posts')
        .where('postType', isEqualTo: 'sos')
        .orderBy('createdAt', descending: true);

    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => _safeParse(doc),
              )
              .whereType<SosPost>() // drop any docs that failed to parse
              .toList(),
        );
  }

  // ---------------------------------------------------------------------------
  // PRIVATE HELPERS
  // ---------------------------------------------------------------------------

  /// Parses a Firestore document without throwing — returns null on error so
  /// a single malformed document never crashes the entire stream.
  SosPost? _safeParse(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    try {
      return SosPost.fromFirestore(doc);
    } catch (e) {
      // In production, swap for a proper logger.
      // ignore: avoid_print
      print('[AdminSosController] Bỏ qua document lỗi ${doc.id}: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // PUBLIC ACTIONS (can be called from UI if needed later)
  // ---------------------------------------------------------------------------

  /// Marks a single SOS post as verified on Firestore.
  Future<void> markAsVerified(String postId) async {
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .update({'isVerified': true});
    } catch (e) {
      // ignore: avoid_print
      print('[AdminSosController] Lỗi khi xác nhận SOS $postId: $e');
      rethrow; // let the UI layer decide how to handle this
    }
  }
}

// =============================================================================
// PROVIDERS
// =============================================================================

/// Main provider — emits [AsyncValue<List<SosPost>>] (loading / error / data).
final adminSosProvider =
    StreamNotifierProvider<AdminSosController, List<SosPost>>(
  AdminSosController.new,
);

/// Derived provider — exposes only the count of unverified SOS posts.
/// Widgets that only need the number watch this instead of [adminSosProvider]
/// so they don't rebuild on unrelated field changes.
final unverifiedSosCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(adminSosProvider).whenData(
        (posts) => posts.where((p) => !p.isVerified).length,
      );
});