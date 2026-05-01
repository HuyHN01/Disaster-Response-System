import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/medical_profile_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MedicalRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> saveMedicalProfile(MedicalProfileModel profile) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Cập nhật trực tiếp vào document của User để đồng bộ nhanh nhất
    await _db.collection('users').doc(uid).set(
      {
        'medicalProfile': profile.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    ); // Merge để không đè mất các thông tin khác như displayName
  }

  final SupabaseClient _supabase = Supabase.instance.client;
  // Lưu hoặc cập nhật hồ sơ y tế
  Future<void> saveProfile(MedicalProfileModel profile) async {
    final data = profile.toJson();

    final supabaseUser = _supabase.auth.currentUser;
    if (supabaseUser != null) {
      await _supabase.from('medical_profiles').upsert({
        'id': supabaseUser.id,
        ...data,
      });
    }

    final firebaseUid = _auth.currentUser?.uid;
    if (firebaseUid != null) {
      await _db.collection('users').doc(firebaseUid).update({
        'medicalProfile': data, // Tạo một trường mới chứa toàn bộ hồ sơ y tế
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Lấy hồ sơ y tế về
  Future<MedicalProfileModel?> getMedicalProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _db.collection('users').doc(uid).get();

    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      // Lấy object 'medicalProfile' nằm bên trong document User
      if (data.containsKey('medicalProfile')) {
        return MedicalProfileModel.fromJson(data['medicalProfile']);
      }
    }
    return null;
  }
}
