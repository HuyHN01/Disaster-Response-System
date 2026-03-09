// lib/features/user_mobile/presentation/mobile_home_screen.dart

import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/features/admin_panel/domain/event_controller.dart';
import 'package:disaster_response_app/features/event_map/presentation/event_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

// =============================================================================
// THEME TOKENS
// =============================================================================
class _MobileColors {
  // Backgrounds
  static const Color scaffold = Color(0xFFF5F7FA);
  static const Color cardBg = Color(0xFFFFFFFF);

  // Emergency (Red/Orange gradient)
  static const Color emergencyStart = Color(0xFFDC2626);
  static const Color emergencyEnd = Color(0xFFEA580C);
  static const Color emergencyText = Colors.white;
  static const Color emergencySubtext = Color(0xFFFFE4E1);

  // Safe (Green)
  static const Color safeStart = Color(0xFF16A34A);
  static const Color safeEnd = Color(0xFF059669);
  static const Color safeText = Colors.white;

  // Text
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  // Menu items
  static const Color menuMap = Color(0xFF2563EB);
  static const Color menuSOS = Color(0xFFDC2626);
  static const Color menuAI = Color(0xFF7C3AED);
  static const Color menuNews = Color(0xFFD97706);

  static const Color menuMapBg = Color(0xFFEFF6FF);
  static const Color menuSOSBg = Color(0xFFFEF2F2);
  static const Color menuAIBg = Color(0xFFF5F3FF);
  static const Color menuNewsBg = Color(0xFFFFFBEB);

  // Call button
  static const Color callButton = Color(0xFFDC2626);
}

// =============================================================================
// MAIN SCREEN
// =============================================================================
class MobileHomeScreen extends ConsumerWidget {
  const MobileHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: _MobileColors.scaffold,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── App Header ─────────────────────────────────────────────────
            SliverToBoxAdapter(child: _Header()),

            // ── Emergency Banner ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: _EmergencyBanner(),
              ),
            ),

            // ── Section: Tính năng ─────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Text(
                  'Tính năng',
                  style: TextStyle(
                    color: _MobileColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            // ── Feature Grid ───────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                delegate: SliverChildListDelegate([
                  _MenuButton(
                    icon: Icons.map_rounded,
                    label: 'Bản đồ\nTình huống',
                    iconColor: _MobileColors.menuMap,
                    bgColor: _MobileColors.menuMapBg,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => EventMapScreen(),)
                      );
                    },
                  ),
                  _MenuButton(
                    icon: Icons.sos_rounded,
                    label: 'Báo cáo\nSOS',
                    iconColor: _MobileColors.menuSOS,
                    bgColor: _MobileColors.menuSOSBg,
                    onTap: () {},
                    isUrgent: true,
                  ),
                  _MenuButton(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Cẩm nang\nSinh tồn (AI)',
                    iconColor: _MobileColors.menuAI,
                    bgColor: _MobileColors.menuAIBg,
                    onTap: () {},
                  ),
                  _MenuButton(
                    icon: Icons.newspaper_rounded,
                    label: 'Tin tức\nThiên tai',
                    iconColor: _MobileColors.menuNews,
                    bgColor: _MobileColors.menuNewsBg,
                    onTap: () {},
                  ),
                ]),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                ),
              ),
            ),

            // ── Section: Hướng dẫn nhanh ───────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 28, 16, 12),
                child: Text(
                  'Hành động khi có thiên tai',
                  style: TextStyle(
                    color: _MobileColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _QuickTipCard(
                    step: '1',
                    title: 'Giữ bình tĩnh & nghe đài',
                    desc:
                        'Theo dõi thông tin chính thức qua radio hoặc ứng dụng này.',
                    color: const Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 10),
                  _QuickTipCard(
                    step: '2',
                    title: 'Sơ tán theo hướng dẫn',
                    desc:
                        'Di chuyển đến điểm tập kết an toàn gần nhất theo bản đồ.',
                    color: const Color(0xFFD97706),
                  ),
                  const SizedBox(height: 10),
                  _QuickTipCard(
                    step: '3',
                    title: 'Báo cáo nếu cần giúp đỡ',
                    desc:
                        'Nhấn SOS hoặc gọi 112 nếu bạn hoặc người thân bị kẹt.',
                    color: const Color(0xFFDC2626),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),

      // ── Floating Emergency FAB ─────────────────────────────────────────────
      floatingActionButton: _EmergencyFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// =============================================================================
// HEADER
// =============================================================================
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Brand + Greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        Icons.warning_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'OmniDisaster',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      color: _MobileColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    children: [
                      TextSpan(text: 'Bình an nhé! '),
                      TextSpan(text: '🙏', style: TextStyle(fontSize: 20)),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Cập nhật tình hình thiên tai gần bạn',
                  style: TextStyle(
                    color: _MobileColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Emergency Call Button
          _CallButton(),
        ],
      ),
    );
  }
}

// =============================================================================
// EMERGENCY CALL BUTTON (top-right)
// =============================================================================
class _CallButton extends StatelessWidget {
  Future<void> _call112() async {
    final uri = Uri(scheme: 'tel', path: '112');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _call112,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFDC2626).withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.phone_rounded, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Khẩn cấp',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '112',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// EMERGENCY BANNER — listens to eventControllerProvider
// =============================================================================
class _EmergencyBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventControllerProvider);

    return eventsAsync.when(
      loading: () => const _BannerSkeleton(),
      error: (_, __) => const _SafeBannerCard(errorMode: true),
      data: (events) {
        final activeEvent = events.where((e) => e.status == 'active').toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (activeEvent.isEmpty) {
          return const _SafeBannerCard();
        }
        return _ActiveEventCard(event: activeEvent.first);
      },
    );
  }
}

// ── Active event: Red/Orange card ──────────────────────────────────────────
class _ActiveEventCard extends StatelessWidget {
  final DisasterEvent event;

  const _ActiveEventCard({required this.event});

  String _localizeType(String type) {
    const map = {
      'typhoon': 'Bão',
      'flood': 'Lũ lụt',
      'storm': 'Dông bão',
      'wildfire': 'Cháy rừng',
      'earthquake': 'Động đất',
      'landslide': 'Sạt lở đất',
    };
    return map[type] ?? type;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_MobileColors.emergencyStart, _MobileColors.emergencyEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _MobileColors.emergencyStart.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative circle
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'CẢNH BÁO ĐANG DIỄN RA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Title
                Text(
                  '⚠️ CẢNH BÁO KHẨN',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 6),

                // Event type chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _localizeType(event.eventType),
                    style: const TextStyle(
                      color: _MobileColors.emergencySubtext,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // CTA Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.map_rounded, size: 17),
                    label: const Text('Xem bản đồ sơ tán'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _MobileColors.emergencyStart,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── No active event: Green safe card ───────────────────────────────────────
class _SafeBannerCard extends StatelessWidget {
  final bool errorMode;
  const _SafeBannerCard({this.errorMode = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: errorMode
              ? [const Color(0xFF6B7280), const Color(0xFF4B5563)]
              : [_MobileColors.safeStart, _MobileColors.safeEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color:
                (errorMode ? const Color(0xFF6B7280) : _MobileColors.safeStart)
                    .withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              errorMode ? Icons.cloud_off_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorMode
                      ? 'Không thể tải dữ liệu'
                      : 'Khu vực của bạn an toàn',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  errorMode
                      ? 'Kiểm tra kết nối và thử lại'
                      : 'Hiện không có sự kiện thiên tai đang diễn ra',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text('✅', style: TextStyle(fontSize: 24)),
        ],
      ),
    );
  }
}

// ── Loading skeleton ────────────────────────────────────────────────────────
class _BannerSkeleton extends StatefulWidget {
  const _BannerSkeleton();

  @override
  State<_BannerSkeleton> createState() => _BannerSkeletonState();
}

class _BannerSkeletonState extends State<_BannerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.4,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.only(top: 16),
        height: 190,
        decoration: BoxDecoration(
          color: Color.lerp(
            const Color(0xFFE5E7EB),
            const Color(0xFFF3F4F6),
            _anim.value,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

// =============================================================================
// MENU BUTTON
// =============================================================================
class _MenuButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback onTap;
  final bool isUrgent;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    required this.onTap,
    this.isUrgent = false,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.03,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: widget.isUrgent
                ? Border.all(
                    color: widget.iconColor.withOpacity(0.3),
                    width: 1.5,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: widget.isUrgent
                    ? widget.iconColor.withOpacity(0.15)
                    : Colors.black.withOpacity(0.05),
                blurRadius: widget.isUrgent ? 16 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: widget.bgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _MobileColors.textPrimary,
                  fontSize: 13,
                  fontWeight: widget.isUrgent
                      ? FontWeight.w700
                      : FontWeight.w600,
                  height: 1.3,
                ),
              ),
              if (widget.isUrgent) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: widget.iconColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'KHẨN CẤP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// QUICK TIP CARD
// =============================================================================
class _QuickTipCard extends StatelessWidget {
  final String step;
  final String title;
  final String desc;
  final Color color;

  const _QuickTipCard({
    required this.step,
    required this.title,
    required this.desc,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _MobileColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    color: _MobileColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// EMERGENCY FLOATING ACTION BUTTON
// =============================================================================
class _EmergencyFAB extends StatelessWidget {
  Future<void> _call112() async {
    final uri = Uri(scheme: 'tel', path: '112');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withOpacity(0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _call112,
            icon: const Icon(
              Icons.phone_rounded,
              size: 20,
              color: Colors.white,
            ),
            label: const Text(
              'Gọi Khẩn Cấp 112',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
