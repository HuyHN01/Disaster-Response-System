// presentation/screens/medical_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/medical_profile_controller.dart';
import '../data/models/medical_profile_model.dart';

class _PC {
  static const Color primary = Color(0xFFDC2626);
  static const Color primaryLight = Color(0xFFFEE2E2);
  static const Color scaffold = Color(0xFFF5F7FA);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color inputBg = Color(0xFFF9FAFB);
  static const Color cardBg = Colors.white;
}

class MedicalSetupScreen extends ConsumerStatefulWidget {
  const MedicalSetupScreen({super.key});

  @override
  ConsumerState<MedicalSetupScreen> createState() => _MedicalSetupScreenState();
}

class _MedicalSetupScreenState extends ConsumerState<MedicalSetupScreen> {
  final _phoneController = TextEditingController();
  final _otherController = TextEditingController();
  final List<TextEditingController> _phoneControllers = [];
  String? _selectedBloodType;
  List<String> _selectedConditions = [];
  int _companionCount = 0;
  bool _isInitialized = false;

  final List<String> _bloodTypes = ['A', 'B', 'AB', 'O', 'Chưa rõ'];
  final List<String> _commonConditions = [
    'Hen suyễn',
    'Tim mạch',
    'Tiểu đường',
    'Huyết áp cao',
    'Dị ứng thuốc',
    'Động kinh',
    'Khác',
  ];

  @override
  void dispose() {
    for (var controller in _phoneControllers) {
      controller.dispose();
    }
    _otherController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _phoneControllers.add(TextEditingController());
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(medicalControllerProvider);

    return Scaffold(
      backgroundColor: _PC.scaffold,
      appBar: _buildAppBar(),
      body: profileAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _PC.primary)),
        error: (err, stack) => Center(
          child: Text(
            'Lỗi: $err',
            style: const TextStyle(color: _PC.textSecondary),
          ),
        ),
        data: (profile) {
          if (profile != null && !_isInitialized) {
            _selectedBloodType = profile.bloodType;
            _phoneController.text = profile.emergencyContact;
            _selectedConditions = List.from(profile.medicalConditions);
            _companionCount = profile.companionCount;
            _isInitialized = true;
          }

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSecurityBanner(),
                    const SizedBox(height: 4),
                    _buildSectionLabel('Nhóm máu'),
                    _buildBloodTypeCard(),
                    const SizedBox(height: 14),
                    _buildSectionLabel('Số người đi cùng'),
                    _buildCompanionCard(),
                    const SizedBox(height: 14),
                    _buildSectionLabel('Bệnh nền & Sức khỏe'),
                    _buildConditionsCard(),
                    const SizedBox(height: 14),
                    _buildSectionLabel('Liên hệ khẩn cấp'),
                    _buildEmergencyCard(),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildSaveButton(),
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(50),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16,
            color: Color(0xFF374151),
          ),
        ),
      ),
      title: const Text(
        'Khai báo Y tế',
        style: TextStyle(
          color: _PC.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: _PC.border),
      ),
    );
  }

  // ── Security Banner ──────────────────────────────────────────────────────────

  Widget _buildSecurityBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _PC.primaryLight,
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 15,
            color: Color(0xFF991B1B),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Thông tin chỉ dùng khi khẩn cấp, được bảo mật hoàn toàn.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF991B1B),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Label ────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _PC.textHint,
          letterSpacing: 0.09,
        ),
      ),
    );
  }

  // ── Card wrapper ─────────────────────────────────────────────────────────────

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _PC.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _PC.border, width: 0.5),
      ),
      child: child,
    );
  }

  Widget _buildCardHeader({
    required Color iconBg,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: iconBg.computeLuminance() > 0.5
                ? Colors.black54
                : Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _PC.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: _PC.textHint),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 0.5,
      color: const Color(0xFFF3F4F6),
      margin: const EdgeInsets.symmetric(vertical: 12),
    );
  }

  // ── Blood Type Card ──────────────────────────────────────────────────────────

  Widget _buildBloodTypeCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            iconBg: const Color(0xFFFEE2E2),
            icon: Icons.water_drop_rounded,
            title: 'Nhóm máu',
            subtitle: 'Chọn nhóm máu chính xác',
          ),
          const SizedBox(height: 12),
          Row(
            children: _bloodTypes.map((type) {
              final isSelected = _selectedBloodType == type;
              final isUnknown = type == 'Chưa rõ';
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedBloodType = type),
                  child: Container(
                    margin: EdgeInsets.only(
                      right: type == _bloodTypes.last ? 0 : 6,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? _PC.primary : _PC.inputBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? _PC.primary : _PC.border,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isUnknown ? '?' : type,
                      style: TextStyle(
                        fontSize: isUnknown ? 11 : 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : isUnknown
                            ? _PC.textHint
                            : const Color(0xFF374151),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Companion Count Card ─────────────────────────────────────────────────────

  Widget _buildCompanionCard() {
    final presets = [
      {'label': 'Một mình', 'value': 0},
      {'label': 'Gia đình', 'value': 2},
      {'label': 'Nhóm lớn', 'value': 5},
    ];

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            iconBg: const Color(0xFFFEF9C3),
            icon: Icons.group_rounded,
            title: 'Người đi cùng',
            subtitle: 'Tổng số người trong nhóm của bạn',
          ),
          _buildDivider(),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Số người đi cùng',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _PC.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Không tính bản thân bạn',
                      style: TextStyle(fontSize: 11, color: _PC.textHint),
                    ),
                  ],
                ),
              ),
              _buildCounter(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: presets.map((p) {
              final val = p['value'] as int;
              final isActive = _companionCount == val;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _companionCount = val),
                  child: Container(
                    margin: EdgeInsets.only(right: p == presets.last ? 0 : 6),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: isActive ? _PC.primaryLight : _PC.inputBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive ? _PC.primary : _PC.border,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      p['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isActive ? _PC.primary : _PC.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCounter() {
    return Row(
      children: [
        _counterBtn(
          icon: Icons.remove,
          onTap: () {
            if (_companionCount > 0) {
              setState(() => _companionCount--);
            }
          },
          isLeft: true,
        ),
        Container(
          width: 48,
          height: 36,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border.symmetric(
              horizontal: BorderSide(color: _PC.border, width: 1.5),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$_companionCount',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _PC.textPrimary,
            ),
          ),
        ),
        _counterBtn(
          icon: Icons.add,
          onTap: () => setState(() => _companionCount++),
          isLeft: false,
        ),
      ],
    );
  }

  Widget _counterBtn({
    required IconData icon,
    required VoidCallback onTap,
    required bool isLeft,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _PC.inputBg,
          border: Border.all(color: _PC.border, width: 1.5),
          borderRadius: isLeft
              ? const BorderRadius.horizontal(left: Radius.circular(10))
              : const BorderRadius.horizontal(right: Radius.circular(10)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: _PC.primary),
      ),
    );
  }

  // ── Conditions Card ──────────────────────────────────────────────────────────

  Widget _buildConditionsCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            iconBg: const Color(0xFFDBEAFE),
            icon: Icons.medical_services_rounded,
            title: 'Tình trạng sức khỏe',
            subtitle: 'Chọn tất cả bệnh đang mắc',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: _commonConditions.map((condition) {
              final isSelected = _selectedConditions.contains(condition);
              final isDashed = condition == 'Khác';
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedConditions.remove(condition);
                    } else {
                      _selectedConditions.add(condition);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _PC.primaryLight
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? _PC.primary
                          : isDashed
                          ? const Color(0xFFD1D5DB)
                          : _PC.border,
                      width: 1.5,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: Text(
                    isDashed ? '+ Khác' : condition,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? _PC.primary
                          : isDashed
                          ? _PC.textHint
                          : const Color(0xFF374151),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedConditions.contains('Khác')) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _otherController,
              decoration: InputDecoration(
                labelText: 'Chi tiết bệnh nền khác',
                hintText: 'Nhập bệnh nền hoặc dị ứng của bạn...',
                hintStyle: const TextStyle(color: _PC.textHint, fontSize: 13),
                filled: true,
                fillColor: _PC.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _PC.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _PC.border, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _PC.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }

  // ── Emergency Contact Card ───────────────────────────────────────────────────

  Widget _buildEmergencyCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            iconBg: const Color(0xFFDCFCE7),
            icon: Icons.phone_rounded,
            title: 'Người thân liên hệ',
            subtitle: 'Được gọi khi có tình huống nguy hiểm',
          ),
          _buildDivider(),
          ..._phoneControllers.asMap().entries.map((entry) {
            int index = entry.key;
            TextEditingController controller = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _PC.inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _PC.border, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 16,
                            color: _PC.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Số điện thoại ${index + 1}',
                                hintStyle: const TextStyle(
                                  color: _PC.textHint,
                                  fontSize: 13,
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Nút xóa (chỉ hiện từ ô thứ 2 trở đi)[cite: 4]
                  if (_phoneControllers.length > 1)
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: _PC.primary,
                      ),
                      onPressed: () {
                        setState(() {
                          _phoneControllers.removeAt(index);
                          controller.dispose();
                        });
                      },
                    ),
                ],
              ),
            );
          }).toList(),

          const SizedBox(height: 10),
          // Nút thêm liên hệ mới[cite: 4]
          GestureDetector(
            onTap: () {
              setState(() {
                _phoneControllers.add(TextEditingController());
              });
            },
            child: const Center(
              child: Text(
                '+ Thêm liên hệ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _PC.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Save Button ──────────────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: _saveInfo,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            height: 52,
            decoration: BoxDecoration(
              color: _PC.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _PC.primary.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 13, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Text(
                  'CẬP NHẬT HỒ SƠ Y TẾ',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Save Logic ───────────────────────────────────────────────────────────────

  void _saveInfo() {
    final contacts = _phoneControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .join(', ');

    final model = MedicalProfileModel(
      bloodType: _selectedBloodType ?? 'Chưa rõ',
      medicalConditions: _selectedConditions,
      companionCount: _companionCount,
      emergencyContact: contacts, // Lưu chuỗi các số điện thoại[cite: 4]
    );

    ref.read(medicalControllerProvider.notifier).saveMedicalInfo(model);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Đã lưu thông tin y tế!'),
        backgroundColor: const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
