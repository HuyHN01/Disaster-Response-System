// lib/features/auth/presentation/auth_gate_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
class AuthGateScreen extends StatelessWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────────
            _TopBar(onBack: () => context.pop()),

            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // ── Illustration card ─────────────────────────────────────
                    _IllustrationCard(),

                    const SizedBox(height: 40),

                    // ── Text block ────────────────────────────────────────────
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

                    // ── CTA: Đăng nhập ────────────────────────────────────────
                    _PrimaryButton(
                      label: 'Đăng nhập bằng Email',
                      icon: Icons.email_outlined,
                      onPressed: () {
                        // TODO: Navigate to EmailInputScreen
                        // context.pushNamed(RouteNames.nameEmailInput);
                      },
                    ),

                    const SizedBox(height: 14),

                    // ── Secondary: Bỏ qua ─────────────────────────────────────
                    _SecondaryButton(
                      label: 'Bỏ qua, tiếp tục không đăng nhập',
                      onPressed: () => context.pop(),
                    ),

                    const Spacer(flex: 3),

                    // ── Bottom note ───────────────────────────────────────────
                    _BottomNote(),

                    const SizedBox(height: 20),
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
// TOP BAR
// =============================================================================
class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
      decoration: const BoxDecoration(
        color: _C.cardBg,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          // Back button
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: _C.textPrimary,
              ),
            ),
          ),

          // Brand
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _C.primary,
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
              color: _C.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
// SECONDARY BUTTON
// =============================================================================
class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SecondaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _C.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          foregroundColor: _C.textSecondary,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _C.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
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