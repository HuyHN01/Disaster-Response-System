// lib/features/auth/presentation/otp_verification_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:disaster_response_app/core/routes/route_names.dart';
import 'package:disaster_response_app/features/auth/domain/email_otp_auth_repository.dart';

// =============================================================================
// SHARED AUTH THEME TOKENS  (keep in shared auth_theme.dart if preferred)
// =============================================================================
class _AuthColors {
  static const Color scaffold = Color(0xFFF5F7FA);
  static const Color cardBg = Color(0xFFFFFFFF);

  static const Color primary = Color(0xFFDC2626);
  static const Color primaryDark = Color(0xFFB91C1C);
  static const Color primaryLight = Color(0xFFFEF2F2);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  static const Color border = Color(0xFFE5E7EB);
  static const Color borderFocus = Color(0xFFDC2626);
  static const Color inputBg = Color(0xFFF9FAFB);
  static const Color errorColor = Color(0xFFDC2626);
  static const Color successColor = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
}

// =============================================================================
// CONSTANTS
// =============================================================================
const int _kOtpLength = 6;
const int _kResendCooldownSec = 60; // seconds before resend is allowed

// =============================================================================
// OTP VERIFICATION SCREEN
// =============================================================================
class OtpVerificationScreen extends ConsumerStatefulWidget {
  /// The email that OTP was sent to. Pass via route extra / constructor.
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  // ── OTP field state ────────────────────────────────────────────────────────
  final List<TextEditingController> _controllers = List.generate(
    _kOtpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _kOtpLength,
    (_) => FocusNode(),
  );

  // ── UI state ───────────────────────────────────────────────────────────────
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  bool _isSuccess = false;

  // ── Countdown state ────────────────────────────────────────────────────────
  int _secondsLeft = _kResendCooldownSec;
  Timer? _countdownTimer;

  String _readableError(Object error) {
    if (error is EmailOtpAuthException) return error.message;
    return 'Mã OTP không đúng hoặc đã hết hạn. Vui lòng thử lại.';
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Countdown helpers
  // ---------------------------------------------------------------------------
  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _secondsLeft = _kResendCooldownSec);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          t.cancel();
        }
      });
    });
  }

  bool get _canResend => _secondsLeft == 0 && !_isResending;

  // ---------------------------------------------------------------------------
  // OTP input helpers
  // ---------------------------------------------------------------------------
  String get _currentOtp => _controllers.map((c) => c.text).join();

  bool get _isOtpComplete => _currentOtp.length == _kOtpLength;

  /// Move focus to the next field, or verify if last field filled.
  void _onDigitChanged(int index, String value) {
    setState(() => _errorMessage = null);

    if (value.length == 1 && index < _kOtpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    // Auto-verify when all fields are filled
    if (_isOtpComplete) {
      _onVerify();
    }
  }

  /// Handle backspace – go to previous field if current is empty.
  void _onKeyEvent(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  Future<void> _onVerify() async {
    if (!_isOtpComplete) return;
    _focusNodes.lastOrNull?.unfocus();

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(emailOtpAuthRepositoryProvider)
          .verifyOtp(email: widget.email, otpCode: _currentOtp);

      if (!mounted) return;

      setState(() => _isSuccess = true);

      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        context.goNamed(RouteNames.nameProfile);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _readableError(e);
        _isSuccess = false;
        // Clear all fields and refocus first field
        for (final c in _controllers) c.clear();
        _focusNodes[0].requestFocus();
      });
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _onResend() async {
    if (!_canResend) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
      _isSuccess = false;
      for (final c in _controllers) c.clear();
    });
    _focusNodes[0].requestFocus();

    try {
      await ref
          .read(emailOtpAuthRepositoryProvider)
          .sendOtp(email: widget.email);

      if (!mounted) return;
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _readableError(e));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  /// Back to email screen to let the user change their email.
  void _onChangeEmail() {
    // pop back to EmailInputScreen
    context.pop();
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),

                    // ── Hero icon ─────────────────────────────────────────────
                    _HeroIcon(
                      icon: _isSuccess
                          ? Icons.check_circle_rounded
                          : Icons.mark_email_unread_rounded,
                      backgroundColor: _isSuccess
                          ? _AuthColors.successLight
                          : _AuthColors.primaryLight,
                      iconColor: _isSuccess
                          ? _AuthColors.successColor
                          : _AuthColors.primary,
                    ),

                    const SizedBox(height: 28),

                    // ── Title block ───────────────────────────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isSuccess
                          ? _TitleBlock(
                              key: const ValueKey('success'),
                              title: 'Xác minh thành công!',
                              subtitle: 'Danh tính của bạn đã được xác nhận.',
                              subtitleColor: _AuthColors.successColor,
                            )
                          : _TitleBlock(
                              key: const ValueKey('normal'),
                              title: 'Nhập mã xác nhận',
                              subtitle:
                                  'Mã OTP gồm 6 chữ số đã được gửi đến\n${widget.email}',
                            ),
                    ),

                    const SizedBox(height: 36),

                    // ── 6-digit OTP input ─────────────────────────────────────
                    _OtpInputRow(
                      controllers: _controllers,
                      focusNodes: _focusNodes,
                      onDigitChanged: _onDigitChanged,
                      onKeyEvent: _onKeyEvent,
                      hasError: _errorMessage != null,
                      isSuccess: _isSuccess,
                    ),

                    // ── Error banner ──────────────────────────────────────────
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      child: _errorMessage != null
                          ? Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: _ErrorBanner(message: _errorMessage!),
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 32),

                    // ── Verify button ─────────────────────────────────────────
                    if (!_isSuccess)
                      _PrimaryButton(
                        label: 'Xác nhận',
                        isLoading: _isVerifying,
                        enabled: _isOtpComplete,
                        onPressed: _onVerify,
                      ),

                    const SizedBox(height: 28),

                    // ── Resend section ────────────────────────────────────────
                    if (!_isSuccess)
                      _ResendSection(
                        secondsLeft: _secondsLeft,
                        canResend: _canResend,
                        isResending: _isResending,
                        onResend: _onResend,
                      ),

                    const SizedBox(height: 16),

                    // ── Change email link ─────────────────────────────────────
                    if (!_isSuccess) _ChangeEmailRow(onTap: _onChangeEmail),

                    const SizedBox(height: 40),
                  ],
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
// OTP INPUT ROW  – 6 individual digit boxes
// =============================================================================
class _OtpInputRow extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final void Function(int index, String value) onDigitChanged;
  final void Function(int index, RawKeyEvent event) onKeyEvent;
  final bool hasError;
  final bool isSuccess;

  const _OtpInputRow({
    required this.controllers,
    required this.focusNodes,
    required this.onDigitChanged,
    required this.onKeyEvent,
    required this.hasError,
    required this.isSuccess,
  });

  Color get _activeBorderColor {
    if (hasError) return _AuthColors.errorColor;
    if (isSuccess) return _AuthColors.successColor;
    return _AuthColors.borderFocus;
  }

  Color get _filledBg {
    if (hasError) return _AuthColors.primaryLight;
    if (isSuccess) return _AuthColors.successLight;
    return _AuthColors.cardBg;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_kOtpLength, (i) {
        return _OtpBox(
          controller: controllers[i],
          focusNode: focusNodes[i],
          activeBorderColor: _activeBorderColor,
          filledBg: _filledBg,
          onChanged: (v) => onDigitChanged(i, v),
          onKeyEvent: (e) => onKeyEvent(i, e),
        );
      }),
    );
  }
}

// =============================================================================
// SINGLE OTP BOX
// =============================================================================
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color activeBorderColor;
  final Color filledBg;
  final ValueChanged<String> onChanged;
  final ValueChanged<RawKeyEvent> onKeyEvent;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.activeBorderColor,
    required this.filledBg,
    required this.onChanged,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = controller.text.isNotEmpty;

    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: onKeyEvent,
      child: SizedBox(
        width: 46,
        height: 58,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isFilled ? filledBg : _AuthColors.inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focusNode.hasFocus
                  ? activeBorderColor
                  : isFilled
                  ? activeBorderColor.withOpacity(0.5)
                  : _AuthColors.border,
              width: focusNode.hasFocus || isFilled ? 1.8 : 1.2,
            ),
            boxShadow: focusNode.hasFocus
                ? [
                    BoxShadow(
                      color: activeBorderColor.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            textAlign: TextAlign.center,
            maxLength: 1,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              color: focusNode.hasFocus || isFilled
                  ? _AuthColors.textPrimary
                  : _AuthColors.textMuted,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              counterText: '',
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// RESEND SECTION
// =============================================================================
class _ResendSection extends StatelessWidget {
  final int secondsLeft;
  final bool canResend;
  final bool isResending;
  final VoidCallback onResend;

  const _ResendSection({
    required this.secondsLeft,
    required this.canResend,
    required this.isResending,
    required this.onResend,
  });

  String get _countdownLabel {
    final m = (secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          // Countdown or "can resend" hint
          if (!canResend && !isResending)
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  color: _AuthColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'Gửi lại mã sau '),
                  TextSpan(
                    text: _countdownLabel,
                    style: const TextStyle(
                      color: _AuthColors.primary,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),

          // Resend button
          AnimatedOpacity(
            opacity: canResend ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 300),
            child: GestureDetector(
              onTap: canResend ? onResend : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _AuthColors.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _AuthColors.border),
                ),
                child: isResending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: _AuthColors.primary,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.refresh_rounded,
                            size: 16,
                            color: _AuthColors.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Gửi lại mã OTP',
                            style: TextStyle(
                              color: _AuthColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CHANGE EMAIL ROW
// =============================================================================
class _ChangeEmailRow extends StatelessWidget {
  final VoidCallback onTap;

  const _ChangeEmailRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: RichText(
            text: const TextSpan(
              style: TextStyle(color: _AuthColors.textSecondary, fontSize: 13),
              children: [
                TextSpan(text: 'Nhập sai email? '),
                TextSpan(
                  text: 'Thay đổi email',
                  style: TextStyle(
                    color: _AuthColors.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: _AuthColors.primary,
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

// =============================================================================
// SHARED WIDGETS (duplicated from email_input_screen.dart;
//   move to auth_shared_widgets.dart for DRY code)
// =============================================================================

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
      decoration: const BoxDecoration(
        color: _AuthColors.cardBg,
        border: Border(bottom: BorderSide(color: _AuthColors.border, width: 1)),
      ),
      child: Row(
        children: [
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
        border: Border.all(color: iconColor.withOpacity(0.15), width: 1.5),
      ),
      child: Icon(icon, color: iconColor, size: 34),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color? subtitleColor;

  const _TitleBlock({
    super.key,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _AuthColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: subtitleColor ?? _AuthColors.textSecondary,
            fontSize: 14,
            height: 1.55,
            fontWeight: subtitleColor != null
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

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
        border: Border.all(color: _AuthColors.errorColor.withOpacity(0.3)),
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

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.45,
      duration: const Duration(milliseconds: 200),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_AuthColors.primary, _AuthColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: _AuthColors.primary.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: ElevatedButton(
            onPressed: (isLoading || !enabled) ? null : onPressed,
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
      ),
    );
  }
}
