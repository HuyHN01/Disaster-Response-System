import 'package:disaster_response_app/core/routes/route_names.dart';
import 'package:disaster_response_app/features/admin_panel/auth/domain/admin_auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class _Colors {
  static const background = Color(0xFF0F0F11);
  static const badgeBg = Color(0xFF1E1E22);
  static const cyan = Color(0xFF22D3EE);
  static const white = Color(0xFFFFFFFF);
  static const rightBg = Color(0xFFFFFFFF);
  static const labelGrey = Color(0xFF6B7280);
  static const borderGrey = Color(0xFFE5E7EB);
  static const inputBg = Color(0xFFF9FAFB);
  static const emergency = Color(0xFFDC2626);
  static const footerGrey = Color(0xFFD1D5DB);
  static const linkGrey = Color(0xFF9CA3AF);
  static const leftFooter = Color(0xFF6B7280);
}

class AdminLoginScreen extends StatelessWidget {
  const AdminLoginScreen({super.key});

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
                  const Text(
                    'OmniDisaster',
                    style: TextStyle(
                      color: _Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Expanded(child: Center(child: _StatusBadge())),
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

class _ConcentricCirclesPainter extends StatelessWidget {
  const _ConcentricCirclesPainter();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CirclesPainter());
  }
}

class _CirclesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.52);
    final paint = Paint()
      ..color = const Color(0xFF2A2A2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const radii = [100.0, 170.0, 240.0, 310.0, 380.0, 450.0];
    for (final r in radii) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
            style: TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

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

class _RightPanel extends ConsumerStatefulWidget {
  const _RightPanel();

  @override
  ConsumerState<_RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends ConsumerState<_RightPanel> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _keepSession = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (_isSubmitting) return;

    final repo = ref.read(adminAuthRepositoryProvider);

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await repo.signInAdmin(
        email: _emailController.text,
        password: _passwordController.text,
        keepSession: _keepSession,
      );

      if (!mounted) return;
      context.go(RouteNames.adminDashboard);
    } on AdminAuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Không thể đăng nhập. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapState = ref.watch(adminBootstrapOpenProvider);
    final canShowRegisterLink = bootstrapState.maybeWhen(
      data: (isOpen) => isOpen,
      orElse: () => false,
    );

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
                const Text(
                  'Cổng Quản trị',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                    fontSize: 36,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Đăng nhập để quản lý ứng phó thiên tai và các trạm cứu hộ.',
                  style: TextStyle(
                    color: _Colors.labelGrey,
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 36),
                _CustomTextField(
                  label: 'Địa chỉ email',
                  controller: _emailController,
                  hintText: 'admin@omnidisaster.org',
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _submitLogin(),
                ),
                const SizedBox(height: 20),
                _CustomTextField(
                  label: 'Mật khẩu',
                  controller: _passwordController,
                  hintText: '••••••••••••',
                  obscureText: _obscurePassword,
                  onSubmitted: (_) => _submitLogin(),
                  suffixIcon: GestureDetector(
                    onTap: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    child: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _Colors.labelGrey,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => setState(() => _keepSession = !_keepSession),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _keepSession
                                ? _Colors.emergency
                                : const Color(0xFFD1D5DB),
                            width: 2,
                          ),
                          color: _keepSession
                              ? _Colors.emergency
                              : Colors.transparent,
                        ),
                        child: _keepSession
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 13)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Duy trì phiên đăng nhập',
                        style: TextStyle(
                          color: _Colors.labelGrey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _Colors.emergency,
                      foregroundColor: _Colors.white,
                      disabledBackgroundColor: _Colors.emergency.withOpacity(0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Đăng nhập',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'Quên mật khẩu?',
                      style: TextStyle(
                        color: _Colors.linkGrey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (canShowRegisterLink)
                  Center(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: _Colors.labelGrey,
                          fontSize: 14,
                        ),
                        children: [
                          const TextSpan(text: 'Chưa có tài khoản? '),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () => context.go(RouteNames.adminRegister),
                              child: const Text(
                                'Đăng ký tại đây',
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
                  )
                else if (bootstrapState.isLoading)
                  const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                const SizedBox(height: 56),
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
                        child: const Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: Color(0xFF9CA3AF),
                        ),
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

class _CustomTextField extends StatelessWidget {
  const _CustomTextField({
    required this.label,
    required this.controller,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF374151),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onSubmitted: onSubmitted,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: _Colors.linkGrey),
            filled: true,
            fillColor: _Colors.inputBg,
            suffixIcon: suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: suffixIcon,
                  )
                : null,
            suffixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: _Colors.borderGrey,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: _Colors.borderGrey,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF6B7280),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
