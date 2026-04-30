import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/medical_profile_model.dart';

class MedicalRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Lưu hoặc cập nhật hồ sơ y tế
  Future<void> saveProfile(MedicalProfileModel profile) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('medical_profiles').upsert({
      'id': user.id, // Dùng ID của User làm khóa chính
      ...profile.toJson(),
    });
  }

  // Lấy hồ sơ y tế về
  Future<MedicalProfileModel?> getProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final data = await _supabase
        .from('medical_profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) return null;
    return MedicalProfileModel.fromJson(data);
  }
}
