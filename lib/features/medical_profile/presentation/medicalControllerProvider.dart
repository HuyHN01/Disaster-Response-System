import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/medical_profile_controller.dart';
import '../data/models/medical_profile_model.dart';

class MedicalSetupScreen extends ConsumerStatefulWidget {
  const MedicalSetupScreen({super.key});

  @override
  ConsumerState<MedicalSetupScreen> createState() => _MedicalSetupScreenState();
}

class _MedicalSetupScreenState extends ConsumerState<MedicalSetupScreen> {
  // Controller cho các ô nhập liệu
  final _phoneController = TextEditingController();
  final _companionController = TextEditingController(text: '0');
  String? _selectedBloodType;

  @override
  Widget build(BuildContext context) {
    // Lắng nghe trạng thái từ Controller
    final profileAsync = ref.watch(medicalControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Hồ sơ Y tế & Cứu hộ")),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Lỗi tải dữ liệu: $err")),
        data: (profile) {
          // Nếu đã có dữ liệu cũ, đổ vào Form (chỉ chạy 1 lần khi load xong)
          if (profile != null && _selectedBloodType == null) {
            _selectedBloodType = profile.bloodType;
            _phoneController.text = profile.emergencyContact;
            _companionController.text = profile.companionCount.toString();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Thông tin này sẽ được gửi kèm khi bạn nhấn SOS",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // 1. Chọn nhóm máu
                DropdownButtonFormField<String>(
                  value: _selectedBloodType,
                  decoration: const InputDecoration(
                    labelText: "Nhóm máu của bạn",
                  ),
                  items: ['A', 'B', 'AB', 'O']
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text("Nhóm máu $type"),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedBloodType = val),
                ),

                const SizedBox(height: 16),

                // 2. Số điện thoại người thân
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: "Số điện thoại người thân",
                    prefixIcon: Icon(Icons.contact_phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),

                const SizedBox(height: 16),

                // 3. Số người đi cùng
                TextField(
                  controller: _companionController,
                  decoration: const InputDecoration(
                    labelText: "Số lượng người đi cùng bạn",
                    prefixIcon: Icon(Icons.people),
                  ),
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 32),

                // Nút Lưu thông tin
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _saveProfile(ref),
                    child: const Text("LƯU HỒ SƠ"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _saveProfile(WidgetRef ref) {
    final newProfile = MedicalProfileModel(
      bloodType: _selectedBloodType ?? 'Chưa xác định',
      medicalConditions: [], // Tú có thể thêm List Checkbox cho phần này sau
      companionCount: int.tryParse(_companionController.text) ?? 0,
      emergencyContact: _phoneController.text,
    );

    // Gọi hàm lưu từ Controller
    ref.read(medicalControllerProvider.notifier).saveMedicalInfo(newProfile);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Đã cập nhật hồ sơ y tế thành công!")),
    );
  }
}
