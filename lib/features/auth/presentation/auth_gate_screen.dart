// lib/features/auth/presentation/auth_gate_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:disaster_response_app/core/routes/route_names.dart';
import 'package:disaster_response_app/features/auth/domain/email_otp_auth_repository.dart';

// =============================================================================
// THEME TOKENS  (consistent with MobileHomeScreen & auth screens)
// =============================================================================
class _C {
  static const Color scaffold      = Color(0xFFF5F7FA);
  static const Color cardBg        = Color(0xFFFFFFFF);
  static const Color primary       = Color(0xFFDC2626);
  static const Color primaryDark   = Color(0xFFB91C1C);
  static const Color primaryLight  = Color(0xFFFEF2F2);
  static const Color textPrimary   = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted     = Color(0xFF9CA3AF);
  static const Color border        = Color(0xFFE5E7EB);
}

// =============================================================================
// AUTH GATE SCREEN
// =============================================================================
class AuthGateScreen extends ConsumerStatefulWidget {
  const AuthGateScreen({super.key});

  @override
  ConsumerState<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends ConsumerState<AuthGateScreen> {
  bool _isGoogleLoading = false;

  Future<void> _onGoogleSignInPressed() async {
    if (_isGoogleLoading) return;

    setState(() => _isGoogleLoading = true);
    try {
      await ref.read(emailOtpAuthRepositoryProvider).signInWithGoogle();
      if (!mounted) return;
      GoRouter.of(context).refresh();
      context.goNamed(RouteNames.nameProfile);
    } on EmailOtpAuthException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Đăng nhập Google thất bại. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.scaffold,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // ── Illustration card ─────────────────────────────────────────
              _IllustrationCard(),

              const SizedBox(height: 40),

              // ── Text block ─────────────────────────────────────────────────
              const Text(
                'Bạn chưa đăng nhập',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _C.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Một số tính năng yêu cầu tài khoản để hoạt động.\nVui lòng đăng nhập để tiếp tục.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _C.textSecondary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 40),

              // ── CTA: Đăng nhập bằng Email ──────────────────────────────────
              _PrimaryButton(
                label: 'Đăng nhập bằng Email',
                icon: Icons.email_outlined,
                onPressed: () => context.pushNamed(
                  RouteNames.nameProfileEmailInput,
                ),
              ),

              const SizedBox(height: 14),

              // ── Secondary: Đăng nhập bằng Google ───────────────────────────
              _SocialLoginButton(
                label: 'Đăng nhập bằng Google',
                icon: Icons.g_mobiledata,
                isLoading: _isGoogleLoading,
                onPressed: _onGoogleSignInPressed,
              ),

              const SizedBox(height: 12),

              // ── Secondary: Đăng nhập bằng Facebook ──────────────────────────
              _SocialLoginButton(
                label: 'Đăng nhập bằng Facebook',
                icon: Icons.facebook,
                onPressed: () {
                  // TODO: Implement Facebook Sign-In
                },
              ),

              const Spacer(flex: 3),

              // ── Bottom note ────────────────────────────────────────────────
              _BottomNote(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SOCIAL LOGIN BUTTON
// =============================================================================
class _SocialLoginButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isLoading;

  const _SocialLoginButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _C.textSecondary,
                ),
              )
            : Icon(icon, color: _C.textSecondary, size: 18),
        label: Text(
          isLoading ? 'Đang đăng nhập...' : label,
          style: const TextStyle(
            color: _C.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _C.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          foregroundColor: _C.textSecondary,
        ),
      ),
    );
  }
}

// =============================================================================
// ILLUSTRATION CARD
// =============================================================================
class _IllustrationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              color: _C.primaryLight,
              shape: BoxShape.circle,
            ),
          ),
          // Inner icon
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: _C.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _C.primary.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_person_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PRIMARY BUTTON
// =============================================================================
class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.icon,
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
            colors: [_C.primary, _C.primaryDark],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _C.primary.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 18),
          label: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// BOTTOM NOTE
// =============================================================================
class _BottomNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Icon(Icons.info_outline_rounded, size: 13, color: _C.textMuted),
        SizedBox(width: 5),
        Flexible(
          child: Text(
            'Bạn vẫn có thể dùng bản đồ và xem tin tức mà không cần đăng nhập.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _C.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}