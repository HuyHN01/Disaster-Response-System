// lib/features/citizen_news/presentation/citizen_news_screen.dart

import 'package:disaster_response_app/features/citizen_news/domain/citizen_news_controller.dart';
import 'package:disaster_response_app/features/citizen_news/presentation/citizen_news_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// =============================================================================
// THEME TOKENS
// =============================================================================
class _NC {
  static const Color bg = Color(0xFFF5F6FA);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFEEF0F4);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color brandRed = Color(0xFFDC2626);
  static const Color brandRedBg = Color(0xFFFEE2E2);
  static const Color brandRedLight = Color(0xFFFF6B6B);
  static const Color news = Color(0xFF0EA5E9);   // sky-500
  static const Color newsBg = Color(0xFFE0F2FE); // sky-100
  static const Color directive = Color(0xFFEA580C);   // orange-600
  static const Color directiveBg = Color(0xFFFFF7ED); // orange-50
  static const Color directiveBorder = Color(0xFFFED7AA); // orange-200
  static const Color shadow = Color(0x0D000000);
}

// =============================================================================
// MAIN SCREEN
// =============================================================================
class CitizenNewsScreen extends ConsumerWidget {
  const CitizenNewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(citizenNewsProvider);

    return Scaffold(
      backgroundColor: _NC.bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [const _AppBar()],
        body: newsAsync.when(
          loading: () => const _LoadingState(),
          error: (e, _) => _ErrorState(message: e.toString()),
          data: (posts) {
            if (posts.isEmpty) return const _EmptyState();

            return RefreshIndicator(
              color: _NC.brandRed,
              onRefresh: () async =>
                  ref.refresh(citizenNewsProvider),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: posts.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                itemBuilder: (_, i) =>
                    _NewsCard(post: posts[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// APP BAR
// =============================================================================
class _AppBar extends StatelessWidget {
  const _AppBar();

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      snap: true,
      pinned: false,
      backgroundColor: _NC.brandRed,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.feed_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Tin tức & Cảnh báo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cập nhật từ Ban Chỉ huy Phòng chống Thiên tai',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.80),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// NEWS CARD
// =============================================================================
class _NewsCard extends StatelessWidget {
  final CitizenNewsPost post;

  const _NewsCard({required this.post});

  static final _dateFmt =
      DateFormat('HH:mm  •  dd/MM/yyyy');

  String get _dateStr =>
      _dateFmt.format(post.createdAt.toLocal());

  @override
  Widget build(BuildContext context) {
    final isDirective = post.isDirective;

    return Material(
      color: _NC.cardBg,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                CitizenNewsDetailScreen(post: post),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        splashColor: (isDirective ? _NC.directive : _NC.news)
            .withOpacity(0.06),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isDirective
                  ? _NC.directiveBorder
                  : _NC.border,
              width: isDirective ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
            // Subtle left accent bar for directives
            gradient: isDirective
                ? const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFFFFBF5),
                      Color(0xFFFFFFFF),
                    ],
                    stops: [0.0, 0.15],
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Directive: nổi bật full-width warning banner
              if (isDirective)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 6, horizontal: 14),
                  decoration: const BoxDecoration(
                    color: _NC.directive,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.campaign_rounded,
                          color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'CÔNG ĐIỆN KHẨN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge + date row (chỉ hiển thị badge cho news)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (!isDirective) ...[
                          _NewsBadge(),
                          const SizedBox(width: 8),
                        ],

                        // Attachment icon
                        if (post.attachmentUrl != null) ...[
                          const Icon(Icons.attach_file_rounded,
                              size: 14, color: _NC.textMuted),
                          const SizedBox(width: 4),
                        ],

                        const Spacer(),

                        // Date
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 12, color: _NC.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              _dateStr,
                              style: const TextStyle(
                                color: _NC.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Title
                    Text(
                      post.title,
                      style: TextStyle(
                        color: isDirective
                            ? _NC.directive
                            : _NC.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (post.attachmentUrl != null) ...[
                      const SizedBox(height: 10),
                      _AttachmentChip(
                          name: post.attachmentName),
                    ],

                    const SizedBox(height: 10),

                    // "Đọc thêm" affordance
                    Row(
                      children: [
                        Text(
                          'Đọc toàn bộ',
                          style: TextStyle(
                            color: isDirective
                                ? _NC.directive
                                : _NC.news,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: isDirective
                              ? _NC.directive
                              : _NC.news,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SMALL WIDGETS
// =============================================================================

class _NewsBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _NC.newsBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.article_rounded,
              size: 11, color: _NC.news),
          SizedBox(width: 4),
          Text(
            'TIN TỨC',
            style: TextStyle(
              color: _NC.news,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  final String? name;
  const _AttachmentChip({this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file_rounded,
              size: 14, color: Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name ?? 'Tệp đính kèm',
              style: const TextStyle(
                color: Color(0xFF1D4ED8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// STATES
// =============================================================================

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const _ShimmerCard(),
    );
  }
}

class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard();
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _ctrl.repeat(reverse: true);
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
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          decoration: BoxDecoration(
            color: _NC.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _NC.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Bone(width: 60, height: 18, radius: 6),
              const SizedBox(height: 12),
              _Bone(width: double.infinity, height: 16, radius: 6),
              const SizedBox(height: 6),
              _Bone(width: 200, height: 16, radius: 6),
              const SizedBox(height: 10),
              _Bone(width: 120, height: 12, radius: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const _Bone(
      {required this.width,
      required this.height,
      required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EBF0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _NC.newsBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.feed_outlined,
                  color: _NC.news, size: 38),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chưa có tin tức',
              style: TextStyle(
                color: _NC.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chưa có bản tin hay cảnh báo nào.\nKéo xuống để làm mới.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _NC.textSecondary,
                  fontSize: 14,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _NC.brandRedBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: _NC.brandRed, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Không thể tải tin tức',
              style: TextStyle(
                color: _NC.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _NC.textMuted, fontSize: 12),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}