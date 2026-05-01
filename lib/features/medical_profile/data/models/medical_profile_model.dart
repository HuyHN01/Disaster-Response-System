class MedicalProfileModel {
  final String bloodType;
  final List<String> medicalConditions; // Danh sách bệnh nền
  final int companionCount;
  final String emergencyContact;
  MedicalProfileModel({
    required this.bloodType,
    required this.medicalConditions,
    required this.companionCount,
    required this.emergencyContact,
  });

  // Chuyển từ JSON (khi lấy dữ liệu từ Supabase/Firebase) sang Object
  factory MedicalProfileModel.fromJson(Map<String, dynamic> json) {
    return MedicalProfileModel(
      bloodType: json['blood_type'] ?? '',
      medicalConditions: List<String>.from(json['medical_conditions'] ?? []),
      companionCount: json['companion_count'] ?? 0,
      emergencyContact: json['emergency_contact'] ?? '',
    );
  }

  // Chuyển từ Object sang Map để lưu lên cơ sở dữ liệu
  Map<String, dynamic> toJson() {
    return {
      'blood_type': bloodType,
      'medical_conditions': medicalConditions,
      'companion_count': companionCount,
      'emergency_contact': emergencyContact,
    };
  }
}
