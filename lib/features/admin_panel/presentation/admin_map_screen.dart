// lib/features/admin_panel/presentation/admin_map_screen.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'dart:ui' as ui;
import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/features/admin_panel/rescue_stations/domain/rescue_station_controller.dart';
import 'package:disaster_response_app/features/event_map/domain/community_report_controller.dart';

import 'package:disaster_response_app/features/admin_panel/domain/admin_map_controller.dart';
import 'package:flutter/material.dart';
import 'package:disaster_response_app/features/admin_panel/rescue_stations/presentation/admin_rescue_stations_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:disaster_response_app/core/services/routing/open_route_service.dart';

// =============================================================================
// THEME TOKENS
// =============================================================================
class _C {
  static const Color sosCore = Color(0xFFDC2626);
  static const Color sosRing = Color(0x55DC2626);
  static const Color sosShadow = Color(0x40DC2626);
  static const Color fabBg = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color shadow = Color(0x14000000);
  static const Color sheetBg = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color resolvedGreen = Color(0xFF16A34A);
  static const Color userDot = Color(0xFF2563EB);
  static const Color stationCore = Color(0xFF0EA5E9);
  static const Color stationRing = Color(0x330EA5E9); // Màu nút Locate Me
  static const Color rescueGreen = Color(0xFF16A34A);
  static const Color stationGray = Color(0xFF9CA3AF);
}

// Tọa độ mặc định: Đà Nẵng — trung tâm địa lý Việt Nam
const _kDefaultCenter = LatLng(16.0471, 108.2068);
const _kDefaultZoom = 6.5;

// =============================================================================
// MAIN SCREEN
// =============================================================================
class AdminMapScreen extends ConsumerStatefulWidget {
  const AdminMapScreen({super.key});

  @override
  ConsumerState<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends ConsumerState<AdminMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapCtrl = MapController();

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  String? _activeMarkerId;
  bool _hasFlownToFirstMarker = false;

  // Trạng thái đóng thông báo trống
  bool _isEmptyBannerClosed = false;

  // Tọa độ hiện tại của Admin
  LatLng? _adminLocation;

  // Routing
  LatLng? _selectedDestination;
  String? _selectedMarkerId;
  List<LatLng> _routePoints = [];
  bool _isRouting = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _mapCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // XỬ LÝ LẤY VỊ TRÍ ADMIN (LOCATE ME)
  // ---------------------------------------------------------------------------
  Future<void> _locateAdmin() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled)
        throw 'Vui lòng bật Dịch vụ vị trí (GPS) trên thiết bị.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied)
          throw 'Quyền truy cập vị trí bị từ chối.';
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'Quyền vị trí bị từ chối vĩnh viễn. Vui lòng kiểm tra cài đặt trình duyệt/thiết bị.';
      }

      // Hiện SnackBar báo đang lấy vị trí
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đang tìm vị trí của bạn...'),
          duration: Duration(seconds: 1),
        ),
      );

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _adminLocation = LatLng(pos.latitude, pos.longitude);
        });
      }

      _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 14.0);
      
      // Nếu đã có điểm đến mà vừa cập nhật GPS, tính lại đường đi
      if (_selectedDestination != null && mounted) {
        final communityReportsAsync = ref.read(communityReportsProvider);
        final reports = communityReportsAsync.value ?? [];
        _calculateRoute(reports);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi định vị: $e'),
          backgroundColor: _C.sosCore,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // XỬ LÝ ĐƯỜNG ĐI & GOOGLE MAPS
  // ---------------------------------------------------------------------------
  Future<void> _calculateRoute(List<CommunityReport> reports) async {
    if (_adminLocation == null || _selectedDestination == null) return;
    
    setState(() {
      _isRouting = true;
    });

    try {
      final points = await OpenRouteService.instance.getRoute(
        _adminLocation!,
        _selectedDestination!,
        avoidPoints: reports.map((r) => LatLng(r.latitude, r.longitude)).toList(),
      );

      if (mounted) {
        setState(() {
          _routePoints = points;
          _isRouting = false;
        });
      }
    } catch (e) {
      debugPrint('[ADMIN MAP] Lỗi gọi API OpenRouteService: $e');
      if (mounted) {
        setState(() {
          // Fallback đường chim bay
          _routePoints = [_adminLocation!, _selectedDestination!];
          _isRouting = false;
        });
      }
    }
  }

  void _setDestinationAndRoute(LatLng dest, {String? markerId}) {
    setState(() {
      _selectedDestination = dest;
      _selectedMarkerId = markerId;
    });

    if (_adminLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng bật định vị (Locate Me) trước khi lấy đường đi.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    final communityReportsAsync = ref.read(communityReportsProvider);
    final reports = communityReportsAsync.value ?? [];
    _calculateRoute(reports);
  }

  Future<void> _openGoogleMaps() async {
    if (_adminLocation == null || _selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cần có vị trí của bạn và đánh dấu điểm đến để mở Google Maps.'),
        ),
      );
      return;
    }

    final startLat = _adminLocation!.latitude;
    final startLng = _adminLocation!.longitude;
    final endLat = _selectedDestination!.latitude;
    final endLng = _selectedDestination!.longitude;

    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=$startLat,$startLng'
      '&destination=$endLat,$endLng'
      '&travelmode=driving',
    );

    try {
      final launched = await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể mở Google Maps trên thiết bị này.')),
          );
        }
      }
    } catch (e, st) {
      debugPrint('[ADMIN MAP] Open Google Maps failed: $e\n$st');
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xảy ra lỗi khi mở Google Maps.')),
          );
        }
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(rescueStationControllerProvider);
    final stationList = stationsAsync.value ?? const [];

    final markersAsync = ref.watch(adminMapProvider);
    final communityReportsAsync = ref.watch(communityReportsProvider);
    final communityReports = communityReportsAsync.value ?? const [];

    // Xoá đường đi nếu marker vừa được chọn bị xoá khỏi danh sách
    if (_selectedMarkerId != null) {
      bool found = false;
      if (markersAsync.value?.any((m) => m.postId == _selectedMarkerId) == true) found = true;
      if (stationList.any((s) => s.id == _selectedMarkerId)) found = true;
      if (communityReports.any((r) => r.id == _selectedMarkerId)) found = true;

      if (!found) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedDestination = null;
              _selectedMarkerId = null;
              _routePoints = [];
            });
          }
        });
      }
    }

    ref.listen<AsyncValue<List<SosMapMarker>>>(adminMapProvider, (_, next) {
      final markers = next.value;
      if (markers != null && markers.isNotEmpty) {
        // Có dữ liệu mới -> Reset lại cờ đóng banner để lần sau trống thì hiện lại
        _isEmptyBannerClosed = false;

        if (!_hasFlownToFirstMarker) {
          _hasFlownToFirstMarker = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _mapCtrl.move(
                LatLng(markers.first.latitude, markers.first.longitude),
                12.0,
              );
            }
          });
        }
      }
    });

    final markerList = markersAsync.value ?? const [];

    return Stack(
      children: [
        // ── Bản đồ (Luôn Render) ──────────────────────────────────────────────
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _kDefaultCenter,
              initialZoom: _kDefaultZoom,
              minZoom: 4,
              maxZoom: 19,
              onTap: (tapPosition, latLng) {
                _setDestinationAndRoute(latLng, markerId: null);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.omnidisaster.app',
                tileProvider: NetworkTileProvider(),
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue,
                      strokeWidth: 4.0,
                      pattern: _routePoints.length == 2
                          ? StrokePattern.dashed(segments: [18, 12])
                          : StrokePattern.solid(),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  ...markerList.map((m) => _buildMarker(m)),
                  ...stationList.map(
                    (s) => _buildStationMarker(s),
                  ), // Dùng spread operator (...)
                  ...communityReports.map((r) => _buildCommunityReportMarker(r)),

                  // Vẽ Marker custom nếu người dùng click điểm bất kỳ (không phải thực thể có sẵn)
                  if (_selectedDestination != null && _selectedMarkerId == null)
                    Marker(
                      point: _selectedDestination!,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (_) => _CustomPinDetailSheet(
                              location: _selectedDestination!,
                              onRemove: () {
                                Navigator.of(context).pop();
                                setState(() {
                                  _selectedDestination = null;
                                  _selectedMarkerId = null;
                                  _routePoints = [];
                                });
                              },
                            ),
                          );
                        },
                        child: const _CustomDestinationPin(),
                      ),
                    ),

                  // Vẽ thêm Marker Admin nếu đã lấy được vị trí
                  if (_adminLocation != null)
                    Marker(
                      point: _adminLocation!,
                      width: 56,
                      height: 56,
                      child: const _AdminLocationMarker(),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        ),

        // ── Overlays ────────────────────────────────────────────────────────

        // Loading
        if (markersAsync.isLoading)
          const Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(child: _LoadingChip()),
          ),

        // Error
        if (markersAsync.hasError)
          Positioned(
            top: 16,
            left: 16,
            right: 72,
            child: _ErrorChip(message: markersAsync.error.toString()),
          ),

        // SOS Count (Góc trái)
        if (markerList.isNotEmpty)
          Positioned(
            top: 16,
            left: 16,
            child: _SosCountBadge(count: markerList.length),
          ),

        // Zoom Controls & Locate Me (Góc phải)
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ZoomControls(mapController: _mapCtrl),
              const SizedBox(height: 12),
              _LocateMeButton(onTap: _locateAdmin),
              const SizedBox(height: 12),
              _GoogleMapsButton(onTap: _openGoogleMaps),
            ],
          ),
        ),

        // Empty State Banner (Thu gọn, có nút X)
        if (!markersAsync.isLoading &&
            !markersAsync.hasError &&
            markerList.isEmpty &&
            !_isEmptyBannerClosed)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: _EmptyStateBanner(
              onClose: () => setState(() => _isEmptyBannerClosed = true),
            ),
          ),
      ],
    );
  }

  Marker _buildStationMarker(RescueStation s) {
    return Marker(
      point: LatLng(s.latitude, s.longitude),
      width: 48,
      height: 56,
      child: GestureDetector(
        onTap: () {
          _setDestinationAndRoute(LatLng(s.latitude, s.longitude), markerId: s.id);
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => _StationDetailSheet(station: s),
          );
        },
        child: _RescueMarker(isActive: s.status == 'active'),
      ),
    );
  }

  Marker _buildCommunityReportMarker(CommunityReport report) {
    IconData icon;
    switch (report.type) {
      case 'fallen_tree':
        icon = Icons.park_rounded;
        break;
      case 'flood':
        icon = Icons.water_drop_rounded;
        break;
      case 'road_block':
        icon = Icons.remove_road_rounded;
        break;
      default:
        icon = Icons.warning_rounded;
    }

    return Marker(
      point: LatLng(report.latitude, report.longitude),
      width: 40,
      height: 48,
      child: GestureDetector(
        onTap: () => _onCommunityReportTap(report),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.shade700.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 18,
              ),
            ),
            CustomPaint(
              size: const Size(8, 5),
              painter: _PinTailPainter(color: Colors.orange.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Marker _buildMarker(SosMapMarker m) {
    return Marker(
      point: LatLng(m.latitude, m.longitude),
      width: 56,
      height: 64,
      child: GestureDetector(
        onTap: () => _onMarkerTap(m),
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => _PulsingSosMarker(
            pulseValue: _pulseAnim.value,
            isHighlighted: _activeMarkerId == m.postId,
          ),
        ),
      ),
    );
  }

  void _onCommunityReportTap(CommunityReport report) {
    _setDestinationAndRoute(LatLng(report.latitude, report.longitude), markerId: report.id);
    setState(() => _activeMarkerId = report.id);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CommunityReportDetailSheet(
        report: report,
        onResolved: () async {
          setState(() {
            _selectedDestination = null;
            _selectedMarkerId = null;
            _routePoints.clear();
          });
        },
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _activeMarkerId = null);
    });
  }

  void _onMarkerTap(SosMapMarker marker) {
    _setDestinationAndRoute(LatLng(marker.latitude, marker.longitude), markerId: marker.postId);
    setState(() => _activeMarkerId = marker.postId);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SosDetailSheet(
        marker: marker,
        onVerify: () async {
          Navigator.of(context).pop();
          await _verifyMarker(marker.postId);
        },
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _activeMarkerId = null);
    });
  }

  Future<void> _verifyMarker(String postId) async {
    try {
      await ref.read(adminMapProvider.notifier).markSosAsVerified(postId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text(
                'Đã xử lý tín hiệu SOS',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: _C.resolvedGreen,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: _C.sosCore,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}

// =============================================================================
// RESCUE STATION MARKER
// =============================================================================
class _RescueMarker extends StatelessWidget {
  final bool isActive;

  const _RescueMarker({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final markerColor = isActive ? _C.rescueGreen : _C.stationGray;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: markerColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: markerColor.withOpacity(0.4),
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
          painter: _PinTailPainter(color: markerColor),
        ),
      ],
    );
  }
}

// =============================================================================
// PULSING SOS MARKER
// =============================================================================
class _PulsingSosMarker extends StatelessWidget {
  final double pulseValue;
  final bool isHighlighted;

  const _PulsingSosMarker({
    required this.pulseValue,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    final ringOpacity = (0.7 * (1 - pulseValue)).clamp(0.0, 1.0);
    final ringScale = 0.5 + 0.5 * pulseValue;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: ringScale,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _C.sosRing.withOpacity(ringOpacity),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: isHighlighted ? 42 : 36,
                height: isHighlighted ? 42 : 36,
                decoration: BoxDecoration(
                  color: _C.sosCore,
                  shape: BoxShape.circle,
                  border: isHighlighted
                      ? Border.all(color: Colors.white, width: 2.5)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: _C.sosShadow,
                      blurRadius: isHighlighted ? 20 : 10,
                      spreadRadius: isHighlighted ? 3 : 0,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _PinTailPainter(color: _C.sosCore),
        ),
      ],
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      ui.Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_PinTailPainter o) => o.color != color;
}

// =============================================================================
// SOS DETAIL BOTTOM SHEET
// =============================================================================
class _SosDetailSheet extends StatefulWidget {
  final SosMapMarker marker;
  final VoidCallback onVerify;

  const _SosDetailSheet({required this.marker, required this.onVerify});

  @override
  State<_SosDetailSheet> createState() => _SosDetailSheetState();
}

class _SosDetailSheetState extends State<_SosDetailSheet> {
  bool _verifying = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.marker;
    final timeStr = DateFormat(
      'HH:mm – dd/MM/yyyy',
    ).format(m.createdAt.toLocal());
    final ago = _timeAgo(m.createdAt);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: _C.sheetBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: _C.shadow, blurRadius: 24, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _C.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _C.sosCore,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '⚠ SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tín hiệu Khẩn cấp',
                            style: TextStyle(
                              color: _C.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            ago,
                            style: const TextStyle(
                              color: _C.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: _C.divider, height: 1),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: _C.sosCore,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NỘI DUNG KÊU CỨU',
                            style: TextStyle(
                              color: _C.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            m.content,
                            style: const TextStyle(
                              color: _C.textPrimary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.schedule_rounded,
                        label: 'THỜI GIAN',
                        value: timeStr,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.location_on_rounded,
                        label: 'TỌA ĐỘ',
                        value:
                            '${m.latitude.toStringAsFixed(4)}, ${m.longitude.toStringAsFixed(4)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _verifying
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: _C.divider),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Đóng',
                          style: TextStyle(
                            color: _C.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _verifying
                            ? null
                            : () {
                                setState(() => _verifying = true);
                                widget.onVerify();
                              },
                        icon: _verifying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                        label: Text(
                          _verifying ? 'Đang xử lý...' : 'Đánh dấu đã xử lý',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.resolvedGreen,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }
}

// ── Info tile ────────────────────────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: _C.textMuted),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _C.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: _C.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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
// ZOOM & LOCATE CONTROLS
// =============================================================================
class _ZoomControls extends StatelessWidget {
  final MapController mapController;
  const _ZoomControls({required this.mapController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.fabBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: _C.shadow, blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZBtn(
            icon: Icons.add,
            isTop: true,
            onTap: () => mapController.move(
              mapController.camera.center,
              mapController.camera.zoom + 1,
            ),
          ),
          const Divider(height: 1, color: _C.divider),
          _ZBtn(
            icon: Icons.remove,
            isTop: false,
            onTap: () => mapController.move(
              mapController.camera.center,
              mapController.camera.zoom - 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZBtn extends StatelessWidget {
  final IconData icon;
  final bool isTop;
  final VoidCallback onTap;
  const _ZBtn({required this.icon, required this.isTop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isTop ? const Radius.circular(12) : Radius.zero,
        bottom: !isTop ? const Radius.circular(12) : Radius.zero,
      ),
      child: SizedBox(
        width: 42,
        height: 42,
        child: Icon(icon, size: 20, color: const Color(0xFF374151)),
      ),
    );
  }
}

class _LocateMeButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LocateMeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.fabBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: _C.shadow, blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Icon(Icons.my_location_rounded, size: 20, color: _C.userDot),
        ),
      ),
    );
  }
}

class _GoogleMapsButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GoogleMapsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.fabBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: _C.shadow, blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Icon(Icons.directions_rounded, size: 20, color: Colors.blueAccent),
        ),
      ),
    );
  }
}

// =============================================================================
// HELPER WIDGETS
// =============================================================================
class _SosCountBadge extends StatelessWidget {
  final int count;
  const _SosCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _C.sosCore,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: _C.shadow, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sos_rounded, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            '$count tín hiệu SOS',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingChip extends StatelessWidget {
  const _LoadingChip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: _C.shadow, blurRadius: 10)],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: _C.sosCore),
          ),
          SizedBox(width: 8),
          Text(
            'Đang tải SOS...',
            style: TextStyle(
              color: _C.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorChip extends StatelessWidget {
  final String message;
  const _ErrorChip({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _C.sosCore,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: _C.shadow, blurRadius: 10)],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Lỗi: $message',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Banner Nhỏ Gọn Báo Không Có SOS (Có nút Tắt) ─────────────────────────────
class _EmptyStateBanner extends StatelessWidget {
  final VoidCallback onClose;
  const _EmptyStateBanner({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 340,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: _C.shadow, blurRadius: 16, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _C.resolvedGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: _C.resolvedGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Bản đồ an toàn',
                    style: TextStyle(
                      color: _C.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tất cả SOS đã được xử lý',
                    style: TextStyle(color: _C.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: _C.textMuted,
              ),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ADMIN LOCATION MARKER & CUSTOM PIN
// =============================================================================
class _AdminLocationMarker extends StatelessWidget {
  const _AdminLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _C.userDot.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: _C.userDot, // Màu xanh dương
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomDestinationPin extends StatelessWidget {
  const _CustomDestinationPin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Colors.redAccent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 20),
        ),
        CustomPaint(
          size: const Size(6, 4),
          painter: _PinTailPainter(color: Colors.redAccent),
        ),
      ],
    );
  }
}

class _CustomPinDetailSheet extends StatefulWidget {
  final LatLng location;
  final VoidCallback onRemove;

  const _CustomPinDetailSheet({
    Key? key,
    required this.location,
    required this.onRemove,
  }) : super(key: key);

  @override
  State<_CustomPinDetailSheet> createState() => _CustomPinDetailSheetState();
}

class _CustomPinDetailSheetState extends State<_CustomPinDetailSheet> {
  bool _isLoading = true;
  String? _address;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAddress();
  }

  Future<void> _fetchAddress() async {
    try {
      final lat = widget.location.latitude;
      final lon = widget.location.longitude;
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&accept-language=vi-VN',
      );
      
      final response = await http.get(
        url,
        headers: {'User-Agent': 'com.omnidisaster.app'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _address = data['display_name'] ?? 'Không tìm thấy thông tin địa chỉ.';
            _isLoading = false;
          });
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi tải địa chỉ: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Colors.redAccent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Vị trí đã chọn',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                 icon: const Icon(Icons.close),
                 onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'Tọa độ: ${widget.location.latitude.toStringAsFixed(6)}, ${widget.location.longitude.toStringAsFixed(6)}',
            style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ))
          else if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            )
          else
            Text(
              'Địa chỉ: $_address',
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: widget.onRemove,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Xóa vị trí', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _StationDetailSheet extends ConsumerWidget {
  final RescueStation station;

  const _StationDetailSheet({Key? key, required this.station})
    : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            station.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Trạng thái: ' +
                (station.status == 'active'
                    ? 'Hoạt động'
                    : station.status == 'full'
                    ? 'Đầy'
                    : 'Ngưng hoạt động'),
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    showDialog(
                      context: context,
                      builder: (ctx) =>
                          RescueStationFormDialog(existing: station),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Chỉnh sửa'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    final newStatus = station.status == 'active'
                        ? 'full'
                        : 'active';
                    ref
                        .read(rescueStationControllerProvider.notifier)
                        .updateStation(
                          id: station.id,
                          name: station.name,
                          latitude: station.latitude,
                          longitude: station.longitude,
                          address: station.address,
                          contactPhone: station.contactPhone,
                          capacity: station.capacity,
                          resourcesJson: station.resourcesJson,
                          status: newStatus,
                        );
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: station.status == 'active'
                        ? Colors.orange
                        : Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    station.status == 'active' ? 'Đánh dấu đầy' : 'Đánh dấu HĐ',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref
                  .read(rescueStationControllerProvider.notifier)
                  .softDeleteStation(station.id);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Xóa trạm cứu hộ'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _CommunityReportDetailSheet extends ConsumerStatefulWidget {
  final CommunityReport report;
  final VoidCallback onResolved;

  const _CommunityReportDetailSheet({
    Key? key,
    required this.report,
    required this.onResolved,
  }) : super(key: key);

  @override
  ConsumerState<_CommunityReportDetailSheet> createState() => _CommunityReportDetailSheetState();
}

class _CommunityReportDetailSheetState extends ConsumerState<_CommunityReportDetailSheet> {
  bool _isLoading = false;

  void _resolveReport() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(communityReportControllerProvider).deleteReport(widget.report.id);
      if (mounted) {
        widget.onResolved();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đánh dấu xử lý sự cố thành công.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xử lý: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _getReportTypeName(String type) {
    switch (type) {
      case 'fallen_tree': return 'Cây đổ';
      case 'flood': return 'Ngập lụt';
      case 'road_block': return 'Tắc đường';
      default: return 'Khác';
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final timeStr = DateFormat('HH:mm – dd/MM/yyyy').format(report.createdAt.toLocal());
    final displayType = _getReportTypeName(report.type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.customTypeName != null && report.customTypeName!.isNotEmpty
                          ? 'Sự cố: ${report.customTypeName}'
                          : 'Sự cố: $displayType',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Báo cáo lúc: $timeStr',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _InfoTile(
            icon: Icons.person,
            label: 'Người báo cáo (ID)',
            value: report.reportedBy,
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.notes,
            label: 'Mô tả',
            value: report.description?.isNotEmpty == true ? report.description! : 'Không có mô tả',
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _resolveReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_isLoading ? 'Đang xử lý...' : 'Đã xử lý'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}


