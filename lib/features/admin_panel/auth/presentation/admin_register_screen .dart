import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  Entry point (remove if embedding in a project)
// ─────────────────────────────────────────────
void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniDisaster – Đăng ký',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Inter'),
      home: const AdminRegisterScreen(),
    );
  }
}

// ─────────────────────────────────────────────
//  Color palette (shared with login page)
// ─────────────────────────────────────────────
class _Colors {
  static const background  = Color(0xFF0F0F11);
  static const surface     = Color(0xFF1A1A1D);
  static const badgeBg     = Color(0xFF1E1E22);
  static const cyan        = Color(0xFF22D3EE);
  static const white       = Color(0xFFFFFFFF);
  static const rightBg     = Color(0xFFFFFFFF);
  static const labelGrey   = Color(0xFF6B7280);
  static const borderGrey  = Color(0xFFE5E7EB);
  static const inputBg     = Color(0xFFF9FAFB);
  static const emergency   = Color(0xFFDC2626);
  static const footerGrey  = Color(0xFFD1D5DB);
  static const linkGrey    = Color(0xFF9CA3AF);
  static const leftFooter  = Color(0xFF6B7280);
  static const textDark    = Color(0xFF111827);
  static const textMid     = Color(0xFF374151);
}

// ─────────────────────────────────────────────
//  Root Screen
// ─────────────────────────────────────────────
class AdminRegisterScreen extends StatelessWidget {
  const AdminRegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Colors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          if (isWide) {
            return Row(
              children: const [
                Expanded(child: _LeftPanel()),
                Expanded(child: _RightPanel()),
              ],
            );
          }
          return const _RightPanel();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Left Panel  (identical brand chrome to login)
// ─────────────────────────────────────────────
class _LeftPanel extends StatelessWidget {
  const _LeftPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _Colors.background,
      child: Stack(
        children: [
          const Positioned.fill(child: _ConcentricCirclesPainter()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo
                  const Text(
                    'OmniDisaster',
                    style: TextStyle(
                      color: _Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      letterSpacing: -0.3,
                    ),
                  ),

                  // Center content
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          _StatusBadge(),
                          SizedBox(height: 28),
                          _LeftInfoCard(),
                        ],
                      ),
                    ),
                  ),

                  // Footer links
                  Row(
                    children: const [
                      _FooterLink('CHÍNH SÁCH BẢO MẬT'),
                      SizedBox(width: 28),
                      _FooterLink('QUY TRÌNH AN NINH'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Concentric circles painter
// ─────────────────────────────────────────────
class _ConcentricCirclesPainter extends StatelessWidget {
  const _ConcentricCirclesPainter();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _CirclesPainter());
}

class _CirclesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.52);
    final paint = Paint()
      ..color = const Color(0xFF2A2A2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final r in [100.0, 170.0, 240.0, 310.0, 380.0, 450.0]) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────
//  Status Badge
// ─────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  const _StatusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: _Colors.badgeBg,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color(0xFF2E2E33), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: _Colors.cyan,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Hệ thống vận hành: Tất cả khu vực an toàn',
            style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Left info card (register-specific copy)
// ─────────────────────────────────────────────
class _LeftInfoCard extends StatelessWidget {
  const _LeftInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        color: _Colors.badgeBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E2E33), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _Colors.emergency.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield_outlined,
                    color: _Colors.emergency, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                'Yêu cầu truy cập',
                style: TextStyle(
                  color: _Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Tài khoản mới sẽ được quản trị viên khu vực xét duyệt trước khi kích hoạt. Bạn sẽ nhận được email khi quyền truy cập được cấp.',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Footer link (left panel)
// ─────────────────────────────────────────────
class _FooterLink extends StatelessWidget {
  const _FooterLink(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {},
        child: Text(
          label,
          style: const TextStyle(
            color: _Colors.leftFooter,
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Right Panel – Registration Form
// ─────────────────────────────────────────────
class _RightPanel extends StatefulWidget {
  const _RightPanel();

  @override
  State<_RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<_RightPanel> {
  final _displayNameCtrl  = TextEditingController();
  final _emailCtrl        = TextEditingController();
  final _passwordCtrl     = TextEditingController();
  final _confirmCtrl      = TextEditingController();

  bool _obscurePassword  = true;
  bool _obscureConfirm   = true;
  bool _agreeToTerms     = false;

  // Simple inline validation state
  String? _passwordError;
  String? _confirmError;

  void _validate() {
    final pw = _passwordCtrl.text;
    final cf = _confirmCtrl.text;
    setState(() {
      _passwordError = pw.length < 8 && pw.isNotEmpty
          ? 'Mật khẩu phải có ít nhất 8 ký tự'
          : null;
      _confirmError  = (cf.isNotEmpty && cf != pw)
          ? 'Mật khẩu xác nhận không khớp'
          : null;
    });
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  /// Password strength: 0–4
  int get _strength {
    final p = _passwordCtrl.text;
    if (p.isEmpty) return 0;
    int s = 0;
    if (p.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p)) s++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(p)) s++;
    return s;
  }

  Color get _strengthColor {
    switch (_strength) {
      case 1: return const Color(0xFFEF4444);
      case 2: return const Color(0xFFF97316);
      case 3: return const Color(0xFFEAB308);
      case 4: return const Color(0xFF22C55E);
      default: return _Colors.borderGrey;
    }
  }

  String get _strengthLabel {
    switch (_strength) {
      case 1: return 'Yếu';
      case 2: return 'Trung bình';
      case 3: return 'Tốt';
      case 4: return 'Mạnh';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _Colors.rightBg,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────
                const Text(
                  'Tạo tài khoản',
                  style: TextStyle(
                    color: _Colors.textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 36,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Đăng ký để truy cập quản lý ứng phó thiên tai và trạm cứu hộ.',
                  style: TextStyle(
                    color: _Colors.labelGrey,
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Display Name ───────────────────────────────
                _CustomTextField(
                  label: 'Tên hiển thị',
                  controller: _displayNameCtrl,
                  hintText: 'ví dụ: Nguyễn Văn A',
                  prefixIcon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 18),

                // ── Registration Email ─────────────────────────
                _CustomTextField(
                  label: 'Email đăng ký',
                  controller: _emailCtrl,
                  hintText: 'you@omnidisaster.org',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline_rounded,
                ),
                const SizedBox(height: 18),

                // ── Password ───────────────────────────────────
                _CustomTextField(
                  label: 'Mật khẩu',
                  controller: _passwordCtrl,
                  hintText: 'Tối thiểu 8 ký tự',
                  obscureText: _obscurePassword,
                  prefixIcon: Icons.lock_outline_rounded,
                  errorText: _passwordError,
                  onChanged: (_) => _validate(),
                  suffixIcon: GestureDetector(
                    onTap: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    child: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _Colors.labelGrey,
                      size: 20,
                    ),
                  ),
                ),

                // ── Strength indicator ─────────────────────────
                if (_passwordCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _PasswordStrengthBar(strength: _strength, color: _strengthColor, label: _strengthLabel),
                ],
                const SizedBox(height: 18),

                // ── Confirm Password ───────────────────────────
                _CustomTextField(
                  label: 'Xác nhận mật khẩu',
                  controller: _confirmCtrl,
                  hintText: 'Nhập lại mật khẩu',
                  obscureText: _obscureConfirm,
                  prefixIcon: Icons.lock_outline_rounded,
                  errorText: _confirmError,
                  onChanged: (_) => _validate(),
                  suffixIcon: GestureDetector(
                    onTap: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    child: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _Colors.labelGrey,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Terms checkbox ─────────────────────────────
                GestureDetector(
                  onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(top: 1),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: _agreeToTerms
                                ? _Colors.emergency
                                : const Color(0xFFD1D5DB),
                            width: 2,
                          ),
                          color: _agreeToTerms
                              ? _Colors.emergency
                              : Colors.transparent,
                        ),
                        child: _agreeToTerms
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 13)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: _Colors.labelGrey,
                              fontSize: 13,
                              height: 1.5,
                            ),
                            children: [
                              const TextSpan(text: 'Tôi đồng ý với '),
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () {},
                                  child: const Text(
                                    'Điều khoản dịch vụ',
                                    style: TextStyle(
                                      color: _Colors.emergency,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              const TextSpan(text: ' và '),
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () {},
                                  child: const Text(
                                    'Chính sách bảo mật',
                                    style: TextStyle(
                                      color: _Colors.emergency,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Submit button ──────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _agreeToTerms ? () {} : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _Colors.emergency,
                      disabledBackgroundColor:
                          _Colors.emergency.withOpacity(0.4),
                      foregroundColor: _Colors.white,
                      disabledForegroundColor: _Colors.white.withOpacity(0.7),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Tạo tài khoản',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Already have an account ────────────────────
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: _Colors.labelGrey,
                        fontSize: 14,
                      ),
                      children: [
                        const TextSpan(text: 'Đã có tài khoản? '),
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () {},
                            child: const Text(
                              'Đăng nhập tại đây',
                              style: TextStyle(
                                color: _Colors.emergency,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 56),

                // ── Footer ─────────────────────────────────────
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.shield_outlined,
                            size: 16, color: Color(0xFF9CA3AF)),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'KHUNG ỨNG PHÓ THỐNG NHẤT V4.2',
                        style: TextStyle(
                          color: _Colors.footerGrey,
                          fontSize: 10,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Password strength bar
// ─────────────────────────────────────────────
class _PasswordStrengthBar extends StatelessWidget {
  const _PasswordStrengthBar({
    required this.strength,
    required this.color,
    required this.label,
  });

  final int strength;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: i < strength ? color : _Colors.borderGrey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            'Độ mạnh mật khẩu: $label',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Reusable Custom Text Field
// ─────────────────────────────────────────────
class _CustomTextField extends StatelessWidget {
  const _CustomTextField({
    required this.label,
    required this.controller,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _Colors.textMid,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: const TextStyle(color: _Colors.textDark, fontSize: 15),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: _Colors.linkGrey),
            errorText: errorText,
            errorStyle: const TextStyle(
              color: Color(0xFFEF4444),
              fontSize: 12,
            ),
            filled: true,
            fillColor: _Colors.inputBg,
            prefixIcon: prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 14, right: 10),
                    child: Icon(prefixIcon,
                        color: _Colors.labelGrey, size: 20),
                  )
                : null,
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: suffixIcon,
                  )
                : null,
            suffixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            contentPadding: EdgeInsets.symmetric(
              horizontal: prefixIcon != null ? 0 : 18,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: _Colors.borderGrey, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: _Colors.borderGrey, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF6B7280), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}