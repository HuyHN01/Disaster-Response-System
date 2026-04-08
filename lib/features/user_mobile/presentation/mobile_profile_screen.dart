// lib/features/user_mobile/presentation/mobile_profile_screen.dart

import 'package:flutter/material.dart';

// =============================================================================
// MOBILE PROFILE SCREEN
// =============================================================================
class MobileProfileScreen extends StatelessWidget {
  const MobileProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Profile Header ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hồ sơ cá nhân',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Quản lý thông tin và cài đặt tài khoản của bạn',
                      style: TextStyle(
                        color: const Color(0xFF6B7280),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Placeholder Content ────────────────────────────────────────
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        size: 40,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Chưa triển khai',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tính năng hồ sơ cá nhân đang được phát triển.\nVui lòng quay lại sau.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF6B7280),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
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
