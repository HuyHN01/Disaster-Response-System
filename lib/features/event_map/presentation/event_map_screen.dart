// lib/features/event_map/presentation/event_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:ui' as ui;

// =============================================================================
// THEME TOKENS
// =============================================================================
class _MapColors {
  static const Color userDot = Color(0xFF2563EB);
  static const Color userDotRing = Color(0x442563EB);
  static const Color sosRed = Color(0xFFDC2626);
  static const Color sosRedBg = Color(0xFFFEE2E2);
  static const Color rescueGreen = Color(0xFF16A34A);
  static const Color rescueGreenBg = Color(0xFFDCFCE7);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color shadow = Color(0x1A000000);
  static const Color fabBg = Color(0xFFFFFFFF);
}

// =============================================================================
// MOCK DATA
// =============================================================================

// Trung tâm Hà Nội
const LatLng _kUserLocation = LatLng(21.0285, 105.8542);

// SOS ~3km về phía Đông Bắc
const LatLng _kSosLocation = LatLng(21.0512, 105.8724);

// Trạm cứu trợ ~2km về phía Tây Nam
const LatLng _kRescueLocation = LatLng(21.0128, 105.8341);

// =============================================================================
// MAIN SCREEN
// =============================================================================
class EventMapScreen extends StatefulWidget {
  const EventMapScreen({super.key});

  @override
  State<EventMapScreen> createState() => _EventMapScreenState();
}

class _EventMapScreenState extends State<EventMapScreen>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // Bottom sheet drag state
  bool _legendExpanded = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Pulse animation for user location dot
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onSosTapped() {
    showDialog(
      context: context,
      builder: (_) => _SosConfirmDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Full-screen map with overlaid widgets
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Stack(
          children: [
            // ── Full-screen Map ──────────────────────────────────────────
            _MapLayer(
              mapController: _mapController,
              pulseAnim: _pulseAnim,
            ),

            // ── Top-left: Back Button ────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _FloatingBackButton(),
              ),
            ),

            // ── Top-right: Zoom controls ─────────────────────────────────
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: _ZoomControls(mapController: _mapController),
                ),
              ),
            ),

            // ── Center: Locate-me button ─────────────────────────────────
            Positioned(
              right: 14,
              bottom: _legendExpanded ? 272 : 148,
              child: _LocateMeButton(
                onTap: () {
                  _mapController.move(_kUserLocation, 14);
                },
              ),
            ),

            // ── Bottom: Legend + SOS Sheet ───────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomLegendSheet(
                expanded: _legendExpanded,
                onToggle: () =>
                    setState(() => _legendExpanded = !_legendExpanded),
                onSosTap: _onSosTapped,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// MAP LAYER (flutter_map)
// =============================================================================
class _MapLayer extends StatelessWidget {
  final MapController mapController;
  final Animation<double> pulseAnim;

  const _MapLayer({
    required this.mapController,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: const MapOptions(
        initialCenter: _kUserLocation,
        initialZoom: 13.5,
        minZoom: 5,
        maxZoom: 19,
        interactionOptions: InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // Tile layer — OpenStreetMap
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.omnidisaster.app',
          tileProvider: NetworkTileProvider(),
        ),

        // Markers layer
        MarkerLayer(
          markers: [
            // ── SOS Signal marker ────────────────────────────────────────
            Marker(
              point: _kSosLocation,
              width: 56,
              height: 56,
              child: _SosMarker(),
            ),

            // ── Rescue Station marker ────────────────────────────────────
            Marker(
              point: _kRescueLocation,
              width: 56,
              height: 56,
              child: const _RescueMarker(),
            ),

            // ── User Location marker (rendered last = on top) ─────────────
            Marker(
              point: _kUserLocation,
              width: 56,
              height: 56,
              child: _UserLocationMarker(pulseAnim: pulseAnim),
            ),
          ],
        ),

        // Attribution
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// MARKERS
// =============================================================================

// ── User Location: Blue pulsing dot ──────────────────────────────────────────
class _UserLocationMarker extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _UserLocationMarker({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, __) => Container(
              width: 36 * pulseAnim.value,
              height: 36 * pulseAnim.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _MapColors.userDotRing
                    .withOpacity(0.6 * (1 - pulseAnim.value + 0.3)),
              ),
            ),
          ),
          // White ring
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: _MapColors.shadow,
                    blurRadius: 6,
                    offset: Offset(0, 2))
              ],
            ),
          ),
          // Inner blue dot
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _MapColors.userDot,
            ),
          ),
        ],
      ),
    );
  }
}

// ── SOS: Red pin with exclamation ─────────────────────────────────────────────
class _SosMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _MapColors.sosRed,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _MapColors.sosRed.withOpacity(0.45),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ),
        // Pin tail
        CustomPaint(
          size: const Size(10, 6),
          painter: _PinTailPainter(color: _MapColors.sosRed),
        ),
      ],
    );
  }
}

// ── Rescue Station: Green shield ─────────────────────────────────────────────
class _RescueMarker extends StatelessWidget {
  const _RescueMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _MapColors.rescueGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _MapColors.rescueGreen.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.medical_services_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        CustomPaint(
          size: const Size(10, 6),
          painter: _PinTailPainter(color: _MapColors.rescueGreen),
        ),
      ],
    );
  }
}

// ── Pin tail painter (shared) ─────────────────────────────────────────────────
class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTailPainter old) => old.color != color;
}

// =============================================================================
// FLOATING BACK BUTTON
// =============================================================================
class _FloatingBackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: _MapColors.fabBg,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: _MapColors.shadow,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).maybePop(),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: _MapColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ZOOM CONTROLS
// =============================================================================
class _ZoomControls extends StatelessWidget {
  final MapController mapController;
  const _ZoomControls({required this.mapController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _MapColors.fabBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: _MapColors.shadow, blurRadius: 12, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomBtn(
            icon: Icons.add,
            onTap: () => mapController.move(
              mapController.camera.center,
              mapController.camera.zoom + 1,
            ),
            isTop: true,
          ),
          const Divider(height: 1, color: _MapColors.divider),
          _ZoomBtn(
            icon: Icons.remove,
            onTap: () => mapController.move(
              mapController.camera.center,
              mapController.camera.zoom - 1,
            ),
            isTop: false,
          ),
        ],
      ),
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isTop;

  const _ZoomBtn(
      {required this.icon, required this.onTap, required this.isTop});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isTop ? const Radius.circular(12) : Radius.zero,
        bottom: !isTop ? const Radius.circular(12) : Radius.zero,
      ),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, size: 20, color: _MapColors.textPrimary),
      ),
    );
  }
}

// =============================================================================
// LOCATE-ME BUTTON
// =============================================================================
class _LocateMeButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LocateMeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _MapColors.fabBg,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      shadowColor: _MapColors.shadow,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.my_location_rounded,
            size: 20,
            color: _MapColors.userDot,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// BOTTOM LEGEND SHEET
// =============================================================================
class _BottomLegendSheet extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onSosTap;

  const _BottomLegendSheet({
    required this.expanded,
    required this.onToggle,
    required this.onSosTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _MapColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: _MapColors.shadow,
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle + toggle ──────────────────────────────────────
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _MapColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.layers_rounded,
                          size: 18, color: _MapColors.textSecondary),
                      const SizedBox(width: 8),
                      const Text(
                        'Chú thích bản đồ',
                        style: TextStyle(
                          color: _MapColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.expand_less_rounded,
                            size: 22, color: _MapColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Collapsible content ──────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: expanded
                ? _LegendContent(onSosTap: onSosTap)
                : const SizedBox(height: 4),
          ),
        ],
      ),
    );
  }
}

class _LegendContent extends StatelessWidget {
  final VoidCallback onSosTap;
  const _LegendContent({required this.onSosTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend items row
          Row(
            children: [
              _LegendItem(
                color: _MapColors.userDot,
                icon: Icons.location_on_rounded,
                label: 'Vị trí bạn',
              ),
              const SizedBox(width: 12),
              _LegendItem(
                color: _MapColors.sosRed,
                label: 'Tín hiệu SOS',
                customWidget: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: _MapColors.sosRed,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _LegendItem(
                color: _MapColors.rescueGreen,
                icon: Icons.medical_services_rounded,
                label: 'Trạm cứu trợ',
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: _MapColors.divider, height: 1),
          const SizedBox(height: 16),

          // SOS Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withOpacity(0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onSosTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.sos_rounded,
                    color: Colors.white, size: 22),
                label: const Text(
                  'Phát tín hiệu SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single legend item ────────────────────────────────────────────────────────
class _LegendItem extends StatelessWidget {
  final Color color;
  final IconData? icon;
  final String label;
  final Widget? customWidget;

  const _LegendItem({
    required this.color,
    this.icon,
    required this.label,
    this.customWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            customWidget ??
                Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SOS CONFIRM DIALOG
// =============================================================================
class _SosConfirmDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _MapColors.sosRed.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sos_rounded,
                color: _MapColors.sosRed, size: 34),
          ),
          const SizedBox(height: 16),
          const Text(
            'Xác nhận phát SOS?',
            style: TextStyle(
              color: _MapColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tín hiệu SOS và vị trí của bạn sẽ được gửi đến đội cứu hộ gần nhất ngay lập tức.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _MapColors.textSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: _MapColors.divider),
                  ),
                  child: const Text(
                    'Huỷ',
                    style: TextStyle(
                      color: _MapColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // TODO: trigger SOS logic
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 10),
                            Text(
                              'Đã gửi tín hiệu SOS!',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        backgroundColor: _MapColors.sosRed,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _MapColors.sosRed,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Gửi SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}