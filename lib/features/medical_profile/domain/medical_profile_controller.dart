import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/medical_profile_model.dart';
import '../data/repositories/medical_repository.dart';

// Khai báo Provider cho Repository (nếu chưa có ở file khác)
final medicalRepositoryProvider = Provider((ref) => MedicalRepository());

class MedicalProfileController
    extends Notifier<AsyncValue<MedicalProfileModel?>> {
  @override
  AsyncValue<MedicalProfileModel?> build() {
    // Riverpod 3.x yêu cầu hàm build trả về trạng thái ban đầu
    // Tú có thể gọi loadProfile() ngay đây để lấy dữ liệu khi app vừa mở
    Future.microtask(() => loadProfile());
    return const AsyncValue.loading();
  }

  Future<void> loadProfile() async {
    state = const AsyncValue.loading();
    // Dùng ref.read để lấy repository thay vì dùng biến cục bộ
    final repository = ref.read(medicalRepositoryProvider);
    state = await AsyncValue.guard(() => repository.getProfile());
  }

  Future<void> saveMedicalInfo(MedicalProfileModel profile) async {
    state = const AsyncValue.loading();
    final repository = ref.read(medicalRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repository.saveProfile(profile);
      return profile;
    });
  }
}

// 2. Định nghĩa Provider kiểu mới cho Notifier
final medicalControllerProvider =
    NotifierProvider<
      MedicalProfileController,
      AsyncValue<MedicalProfileModel?>
    >(MedicalProfileController.new);
