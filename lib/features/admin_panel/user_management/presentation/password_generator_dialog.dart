import 'dart:math';
import 'package:flutter/material.dart';

/// Hàm hỗ trợ gọi Dialog tạo mật khẩu
/// Trả về chuỗi mật khẩu nếu người dùng nhấn OK, trả về null nếu Hủy
Future<String?> showPasswordGeneratorDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const PasswordGeneratorDialog(),
  );
}

class PasswordGeneratorDialog extends StatefulWidget {
  const PasswordGeneratorDialog({super.key});

  @override
  State<PasswordGeneratorDialog> createState() =>
      _PasswordGeneratorDialogState();
}

class _PasswordGeneratorDialogState extends State<PasswordGeneratorDialog> {
  // --- Bảng màu chuẩn của OmniDisaster ---
  final Color primaryRed = const Color(0xFFDA291C);
  final Color textDark = const Color(0xFF111827);
  final Color textMuted = const Color(0xFF6B7280);
  final Color borderGrey = const Color(0xFFE5E7EB);
  final Color innerBackground = const Color(0xFFF3F4F6);

  // --- State của Form ---
  double _passwordLength = 12; // Mặc định là 12 ký tự
  bool _useUppercase = true;
  bool _useLowercase = true;
  bool _useNumbers = true;
  bool _useSpecials = true;

  String _generatedPassword = "";

  @override
  void initState() {
    super.initState();
    _generatePassword(); // Tạo mật khẩu ngay khi mở Dialog
  }

  // --- Logic tạo mật khẩu ngẫu nhiên ---
  void _generatePassword() {
    const String upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const String lower = 'abcdefghijklmnopqrstuvwxyz';
    const String numbers = '0123456789';
    const String specials = '!@#\$%^&*()_+~`|}{[]:;?><,./-=';

    final selectedGroups = <String>[];
    if (_useUppercase) selectedGroups.add(upper);
    if (_useLowercase) selectedGroups.add(lower);
    if (_useNumbers) selectedGroups.add(numbers);
    if (_useSpecials) selectedGroups.add(specials);

    final chars = selectedGroups.join();

    if (chars.isEmpty) {
      setState(() {
        _generatedPassword = "Vui lòng chọn ít nhất 1 tùy chọn!";
      });
      return;
    }

    final targetLength = _passwordLength.toInt();
    if (targetLength < selectedGroups.length) {
      setState(() {
        _generatedPassword =
            "Độ dài phải lớn hơn hoặc bằng số nhóm ký tự đã chọn.";
      });
      return;
    }

    final rnd = Random.secure();
    final codes = <int>[];

    // Đảm bảo mật khẩu có ít nhất 1 ký tự từ mỗi nhóm đã bật.
    for (final group in selectedGroups) {
      codes.add(group.codeUnitAt(rnd.nextInt(group.length)));
    }

    final remaining = targetLength - codes.length;
    for (var i = 0; i < remaining; i++) {
      codes.add(chars.codeUnitAt(rnd.nextInt(chars.length)));
    }

    // Shuffle để tránh luôn xuất hiện theo thứ tự nhóm cố định.
    for (var i = codes.length - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      final temp = codes[i];
      codes[i] = codes[j];
      codes[j] = temp;
    }

    final newPassword = String.fromCharCodes(codes);

    setState(() {
      _generatedPassword = newPassword;
    });
  }

  void _handleConfirm() {
    if (_generatedPassword.isEmpty ||
        _generatedPassword == "Vui lòng chọn ít nhất 1 tùy chọn!") {
      return; // Ngăn chặn việc submit nếu mật khẩu không hợp lệ
    }

    // TODO: Bạn có thể xử lý logic khác tại đây (ví dụ: copy vào clipboard tự động)

    // Đóng dialog và trả về mật khẩu đã tạo
    Navigator.of(context).pop(_generatedPassword);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent, // Khóa nền trắng tinh
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 5,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 450,
        ), // Dialog nhỏ gọn hơn Avatar Upload
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Tạo mật khẩu tự động",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textMuted),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- 1. Khu vực hiển thị Mật khẩu ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: innerBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderGrey),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _generatedPassword,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textDark,
                          letterSpacing: 1.5,
                          // Mẹo: Dùng font monospace để phân biệt rõ l, I, 0, O
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Nút làm mới (Change)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(Icons.autorenew_rounded, color: primaryRed),
                        tooltip: "Tạo mật khẩu mới",
                        onPressed: _generatePassword,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // --- 2. Slider tùy chỉnh độ dài ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Độ dài mật khẩu",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textDark,
                    ),
                  ),
                  Text(
                    "${_passwordLength.toInt()} ký tự",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: primaryRed,
                  inactiveTrackColor: borderGrey,
                  thumbColor: primaryRed,
                  overlayColor: primaryRed.withOpacity(0.1),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _passwordLength,
                  min: 10,
                  max: 64,
                  divisions: 54,
                  onChanged: (val) {
                    setState(() => _passwordLength = val);
                    _generatePassword(); // Cập nhật lại mật khẩu khi kéo slider
                  },
                ),
              ),
              const SizedBox(height: 24),

              // --- 3. Checkbox cấu hình định dạng ---
              Text(
                "Tùy chọn ký tự",
                style: TextStyle(fontWeight: FontWeight.w600, color: textDark),
              ),
              const SizedBox(height: 12),
              // Dùng Grid 2 cột để bố cục gọn gàng, phù hợp với màn hình Web
              Row(
                children: [
                  Expanded(
                    child: _buildCheckbox("Chữ hoa (A-Z)", _useUppercase, (
                      val,
                    ) {
                      setState(() => _useUppercase = val ?? true);
                      _generatePassword();
                    }),
                  ),
                  Expanded(
                    child: _buildCheckbox("Chữ thường (a-z)", _useLowercase, (
                      val,
                    ) {
                      setState(() => _useLowercase = val ?? true);
                      _generatePassword();
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildCheckbox("Số (0-9)", _useNumbers, (val) {
                      setState(() => _useNumbers = val ?? true);
                      _generatePassword();
                    }),
                  ),
                  Expanded(
                    child: _buildCheckbox("Đặc biệt (!@#...)", _useSpecials, (
                      val,
                    ) {
                      setState(() => _useSpecials = val ?? true);
                      _generatePassword();
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // --- 4. Footer Buttons ---
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(), // Hủy không trả về gì
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      foregroundColor: textMuted,
                    ),
                    child: const Text(
                      "Hủy",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _handleConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Xác nhận & Dùng",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widget helper vẽ Checkbox ---
  Widget _buildCheckbox(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: primaryRed,
                side: BorderSide(color: borderGrey, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(color: textDark, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
