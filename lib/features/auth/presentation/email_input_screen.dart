// lib/features/auth/presentation/email_input_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// =============================================================================
// SHARED AUTH THEME TOKENS  (consistent with MobileHomeScreen)
// =============================================================================
class _AuthColors {
  static const Color scaffold       = Color(0xFFF5F7FA);
  static const Color cardBg         = Color(0xFFFFFFFF);

  static const Color primary        = Color(0xFFDC2626); // emergency red
  static const Color primaryDark    = Color(0xFFB91C1C);
  static const Color primaryLight   = Color(0xFFFEF2F2);

  static const Color textPrimary    = Color(0xFF111827);
  static const Color textSecondary  = Color(0xFF6B7280);
  static const Color textMuted      = Color(0xFF9CA3AF);

  static const Color border         = Color(0xFFE5E7EB);
  static const Color borderFocus    = Color(0xFFDC2626);
  static const Color inputBg        = Color(0xFFF9FAFB);
  static const Color errorColor     = Color(0xFFDC2626);
  static const Color successColor   = Color(0xFF16A34A);
}

// =============================================================================
// EMAIL INPUT SCREEN
// =============================================================================
class EmailInputScreen extends StatefulWidget {
  const EmailInputScreen({super.key});

  @override
  State<EmailInputScreen> createState() => _EmailInputScreenState();
}

class _EmailInputScreenState extends State<EmailInputScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocus      = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Logic placeholders
  // ---------------------------------------------------------------------------
  Future<void> _onSendOtp() async {
    // Dismiss keyboard
    _emailFocus.unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    try {
      // TODO: Implement – call your auth service / API to send OTP
      // e.g. await ref.read(authRepositoryProvider).sendOtp(_emailController.text.trim());

      // Simulate network delay (remove in production)
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      // TODO: Navigate to OTP screen, passing the email
      // context.pushNamed(RouteNames.nameOtpVerification,
      //   extra: _emailController.text.trim());
    } catch (e) {
      // TODO: Map specific error types to user-friendly messages
      setState(() => _errorMessage = 'Không thể gửi mã OTP. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------
  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Vui lòng nhập địa chỉ email';
    final emailReg = RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
    if (!emailReg.hasMatch(v)) return 'Địa chỉ email không hợp lệ';
    return null;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AuthColors.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────────
            _TopBar(onBack: () => context.pop()),

            // ── Scrollable body ──────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),

                      // ── Hero icon ─────────────────────────────────────────
                      _HeroIcon(
                        icon: Icons.shield_rounded,
                        backgroundColor: _AuthColors.primaryLight,
                        iconColor: _AuthColors.primary,
                      ),

                      const SizedBox(height: 28),

                      // ── Title block ───────────────────────────────────────
                      const Text(
                        'Xác minh Email',
                        style: TextStyle(
                          color: _AuthColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Nhập địa chỉ email của bạn để nhận mã xác nhận (OTP) gồm 6 chữ số.',
                        style: TextStyle(
                          color: _AuthColors.textSecondary,
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Email field ───────────────────────────────────────
                      _SectionLabel(label: 'Địa chỉ Email'),
                      const SizedBox(height: 8),
                      _EmailTextField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        validator: _validateEmail,
                        onFieldSubmitted: (_) => _onSendOtp(),
                      ),

                      // ── Inline error banner ───────────────────────────────
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        _ErrorBanner(message: _errorMessage!),
                      ],

                      const SizedBox(height: 32),

                      // ── Send OTP button ───────────────────────────────────
                      _PrimaryButton(
                        label: 'Gửi mã OTP',
                        isLoading: _isLoading,
                        onPressed: _onSendOtp,
                      ),

                      const SizedBox(height: 24),

                      // ── Disclaimer ────────────────────────────────────────
                      _DisclaimerRow(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// OTP VERIFICATION SCREEN
// =============================================================================

// Keep export from same file for convenience; move to own file if needed.
// See otp_verification_screen.dart


// =============================================================================
// SHARED WIDGETS (reused in both screens)
// =============================================================================

/// Top navigation bar with back button + app brand
class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
      decoration: const BoxDecoration(
        color: _AuthColors.cardBg,
        border: Border(
          bottom: BorderSide(color: _AuthColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Back button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: _AuthColors.textPrimary,
                ),
              ),
            ),
          ),

          // Brand logo
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _AuthColors.primary,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.warning_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'DisasterResponse',
            style: TextStyle(
              color: _AuthColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular hero icon container
class _HeroIcon extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  const _HeroIcon({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: iconColor.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Icon(icon, color: iconColor, size: 34),
    );
  }
}

/// Small label above an input
class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _AuthColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    );
  }
}

/// Styled email TextFormField
class _EmailTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;

  const _EmailTextField({
    required this.controller,
    required this.focusNode,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      style: const TextStyle(
        color: _AuthColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: _AuthColors.inputBg,
        hintText: 'example@email.com',
        hintStyle: const TextStyle(
          color: _AuthColors.textMuted,
          fontSize: 15,
        ),
        prefixIcon: const Icon(
          Icons.email_outlined,
          color: _AuthColors.textSecondary,
          size: 20,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _AuthColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _AuthColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: _AuthColors.borderFocus, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: _AuthColors.errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: _AuthColors.errorColor, width: 1.5),
        ),
        errorStyle: const TextStyle(
          color: _AuthColors.errorColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Error banner card
class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _AuthColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _AuthColors.errorColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: _AuthColors.errorColor,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _AuthColors.errorColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary CTA button with loading state
class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_AuthColors.primary, _AuthColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _AuthColors.primary.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.2,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Disclaimer / privacy note
class _DisclaimerRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          size: 14,
          color: _AuthColors.textMuted,
        ),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'Thông tin email chỉ được dùng để xác minh danh tính và không được chia sẻ cho bên thứ ba.',
            style: TextStyle(
              color: _AuthColors.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}