// lib/features/event_map/presentation/event_map_screen.dart

import 'dart:ui' as ui;

import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/core/database/db_provider.dart';
import 'package:disaster_response_app/core/services/firebase/sync_service.dart';
import 'package:disaster_response_app/core/services/routing/open_route_service.dart';
import 'package:disaster_response_app/features/event_map/domain/event_map_controller.dart';
import 'package:disaster_response_app/features/event_map/domain/community_report_controller.dart';
import 'package:disaster_response_app/features/admin_panel/rescue_stations/domain/rescue_station_controller.dart';
import 'package:disaster_response_app/features/admin_panel/rescue_stations/domain/rescue_station_repository.dart';
import 'package:drift/drift.dart' as drift;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

// Provider to track the currently checked-in station ID across the map screen
final currentCheckedInStationProvider = StateProvider<String?>((ref) => null);

// =============================================================================
// THEME TOKENS  (unchanged)
// =============================================================================
class _MapColors {
  static const Color userDot = Color(0xFF2563EB);
  static const Color userDotRing = Color(0x442563EB);
  static const Color sosRed = Color(0xFFDC2626);
  static const Color rescueGreen = Color(0xFF16A34A);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color shadow = Color(0x1A000000);
  static const Color fabBg = Color(0xFFFFFFFF);
}

// =============================================================================
// FALLBACK — dùng khi geolocator chưa trả kết quả hoặc bị từ chối
// =============================================================================
const LatLng _kFallbackLocation = LatLng(21.0285, 105.8542); // Hà Nội

// =============================================================================
// GEOLOCATION HELPERS
// =============================================================================

/// Log helper — dễ tìm trên terminal với prefix [GEO]
// ignore: avoid_print
void _geoLog(String msg) => print('[GEO] $msg');

/// Error codes để UI biết phải hiển thị hành động gì (retry vs open settings).
enum _LocErrCode {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unableToDetermine,
}

/// Xin quyền và lấy tọa độ hiện tại.
/// Log từng bước ra console để dễ debug.
/// Ném [LocationException] có message Tiếng Việt + [_LocErrCode] cho từng case.
Future<Position> _determinePosition() async {
  _geoLog('▶ _determinePosition() bắt đầu');

  // ── 1. Kiểm tra GPS service ───────────────────────────────────────────────
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  _geoLog('isLocationServiceEnabled = $serviceEnabled');
  if (!serviceEnabled) {
    throw const LocationException(
      'GPS đang tắt. Vui lòng bật Location Service và thử lại.',
      code: _LocErrCode.serviceDisabled,
    );
  }

  // ── 2. Kiểm tra quyền hiện tại ───────────────────────────────────────────
  LocationPermission permission = await Geolocator.checkPermission();
  _geoLog('checkPermission() = $permission');

  // ── 3. Xin quyền nếu chưa có ────────────────────────────────────────────
  if (permission == LocationPermission.denied) {
    _geoLog('Đang gọi requestPermission()...');
    permission = await Geolocator.requestPermission();
    _geoLog('requestPermission() trả về = $permission');
  }

  // ── 4. Kiểm tra kết quả sau khi xin ─────────────────────────────────────
  switch (permission) {
    case LocationPermission.denied:
      throw const LocationException(
        'Quyền vị trí bị từ chối. Hãy cho phép trong hộp thoại.',
        code: _LocErrCode.permissionDenied,
      );
    case LocationPermission.deniedForever:
      throw const LocationException(
        'Quyền vị trí bị từ chối vĩnh viễn.\n'
        'Vào Cài đặt → Ứng dụng → OmniDisaster → Quyền để cấp lại.',
        code: _LocErrCode.permissionDeniedForever,
      );
    case LocationPermission.unableToDetermine:
      // Xảy ra khi manifest thiếu permission declaration
      throw const LocationException(
        'Không thể xác định quyền vị trí.\n'
        'Kiểm tra AndroidManifest.xml đã có ACCESS_FINE_LOCATION chưa.',
        code: _LocErrCode.unableToDetermine,
      );
    case LocationPermission.always:
    case LocationPermission.whileInUse:
      _geoLog('Quyền OK ($permission) — đang lấy tọa độ...');
      break;
  }

  // ── 5. Lấy tọa độ ───────────────────────────────────────────────────────
  final pos = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 20),
    ),
  );

  _geoLog(
    '✅ Tọa độ: lat=${pos.latitude}, lng=${pos.longitude}, '
    'accuracy=${pos.accuracy.toStringAsFixed(1)}m',
  );
  return pos;
}

/// Tín hiệu SOS giả định ~3 km về phía ĐB so với [center].
LatLng _mockSosLocation(LatLng center) =>
    LatLng(center.latitude + 0.022, center.longitude + 0.018);

// =============================================================================
// CUSTOM EXCEPTION
// =============================================================================
class LocationException implements Exception {
  final String message;
  final _LocErrCode code;

  const LocationException(
    this.message, {
    this.code = _LocErrCode.permissionDenied,
  });

  @override
  String toString() => 'LocationException[$code]: $message';
}

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

  // ── Location state ───────────────────────────────────────────────────────
  /// null = GPS chưa lấy được (loading hoặc lỗi)
  LatLng? _userLocation;
  bool _locationLoading = true;
  String? _locationError;
  _LocErrCode? _locationErrCode;

  // ── UI state ─────────────────────────────────────────────────────────────
  // ── Routing state (for external Google Maps directions) ──────────────────
  LatLng? _routeDestination;
  RescueStation? _targetStation;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Pulse animation for user location dot
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Fetch real GPS on startup — non-blocking
    _initLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LOCATION LOGIC
  // ---------------------------------------------------------------------------

  Future<void> _initLocation() async {
    _geoLog('_initLocation() called. mounted=$mounted');
    if (!mounted) return;
    setState(() {
      _locationLoading = true;
      _locationError = null;
      _locationErrCode = null;
    });

    try {
      final pos = await _determinePosition();
      if (!mounted) return;
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _userLocation = latLng;
        _locationLoading = false;
        _locationError = null;
        _locationErrCode = null;
      });
      // Fly camera to real GPS position
      _mapController.move(latLng, 14.5);
      _geoLog('Camera moved to real GPS position.');
    } on LocationException catch (e) {
      _geoLog('LocationException caught: $e');
      if (!mounted) return;
      setState(() {
        _locationLoading = false;
        _locationError = e.message;
        _locationErrCode = e.code;
        _userLocation = _kFallbackLocation; // still show a usable map
      });
      _showLocationBanner(e.message, e.code);
    } catch (e, st) {
      _geoLog('Unknown error caught: $e\n$st');
      if (!mounted) return;
      setState(() {
        _locationLoading = false;
        _locationError = e.toString();
        _locationErrCode = null;
        _userLocation = _kFallbackLocation;
      });
      _showLocationBanner('Lỗi không xác định: $e', null);
    }
  }

  void _showLocationBanner(String message, _LocErrCode? code) {
    if (!mounted) return;
    final isDeniedForever =
        code == _LocErrCode.permissionDeniedForever ||
        code == _LocErrCode.unableToDetermine;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.location_off_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        action: isDeniedForever
            ? SnackBarAction(
                label: 'Cài đặt',
                textColor: Colors.white,
                onPressed: Geolocator.openAppSettings,
              )
            : SnackBarAction(
                label: 'Thử lại',
                textColor: Colors.white,
                onPressed: _initLocation,
              ),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  void _locateMe() {
    final dest = _userLocation ?? _kFallbackLocation;
    _mapController.move(dest, 15);
  }

  void _onSosTapped() {
    showDialog(
      context: context,
      builder: (_) => _SosConfirmDialog(
        parentContext: context,
        currentLocation: _userLocation,
      ),
    );
  }

  void _onRouteDestinationChanged(LatLng? destination, RescueStation? station) {
    if (_isSameLatLng(_routeDestination, destination) &&
        _targetStation?.id == station?.id)
      return;
    if (!mounted) return;

    setState(() {
      _routeDestination = destination;
      _targetStation = station;
    });
  }

  bool _isSameLatLng(LatLng? a, LatLng? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;

    const epsilon = 0.0000001;
    return (a.latitude - b.latitude).abs() < epsilon &&
        (a.longitude - b.longitude).abs() < epsilon;
  }

  Future<LatLng?> _resolveStartLocationForDirections() async {
    if (_userLocation != null) return _userLocation;

    try {
      final pos = await _determinePosition();
      if (!mounted) return null;

      final location = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _userLocation = location;
        _locationLoading = false;
        _locationError = null;
        _locationErrCode = null;
      });
      return location;
    } on LocationException catch (e) {
      _showLocationBanner(e.message, e.code);
      return null;
    } catch (_) {
      _showLocationBanner('Không lấy được vị trí hiện tại để chỉ đường.', null);
      return null;
    }
  }

  Future<void> _openGoogleMapsDirections() async {
    final destination = _routeDestination;
    if (destination == null) {
      _showDirectionError('Không có trạm cứu trợ để chỉ đường.');
      return;
    }

    final origin = await _resolveStartLocationForDirections();
    if (origin == null) {
      _showDirectionError('Không xác định được vị trí hiện tại của bạn.');
      return;
    }

    final startLat = origin.latitude;
    final startLng = origin.longitude;
    final endLat = destination.latitude;
    final endLng = destination.longitude;

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
        _showDirectionError('Không thể mở Google Maps trên thiết bị này.');
      }
    } catch (e, st) {
      debugPrint('[MAP] Open Google Maps failed: $e\n$st');
      _showDirectionError('Đã xảy ra lỗi khi mở Google Maps.');
    }
  }

  void _showDirectionError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showLegendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Chú thích bản đồ',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _legendDialogItem(
              color: _MapColors.userDot,
              icon: Icons.location_on_rounded,
              label: 'Vị trí hiện tại của bạn',
            ),
            const SizedBox(height: 12),
            _legendDialogItem(
              color: _MapColors.rescueGreen,
              icon: Icons.medical_services_rounded,
              label: 'Trạm cứu trợ',
            ),
            const SizedBox(height: 12),
            _legendDialogItem(
              color: Colors.orange.shade700,
              icon: Icons.warning_rounded,
              label: 'Cộng đồng báo cáo',
            ),
            const SizedBox(height: 12),
            _legendDialogItem(
              color: _MapColors.sosRed,
              customWidget: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: _MapColors.sosRed,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              label: 'Vị trí phát tín hiệu SOS',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _legendDialogItem({
    required Color color,
    required String label,
    IconData? icon,
    Widget? customWidget,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: customWidget ?? Icon(icon, color: color, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: _MapColors.textPrimary),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final effectiveLocation = _userLocation ?? _kFallbackLocation;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Stack(
          children: [
            // ── Full-screen Map ──────────────────────────────────────────
            Positioned.fill(
              child: _MapLayer(
                mapController: _mapController,
                pulseAnim: _pulseAnim,
                userLocation: effectiveLocation,
                onRouteTargetChanged: _onRouteDestinationChanged,
              ),
            ),

            // ── GPS loading chip or error banner ────────────────────────
            if (_locationLoading || _locationError != null)
              Positioned(
                top: topPadding + 70,
                left: 0,
                right: 0,
                child: Center(
                  child: _locationLoading
                      ? const _GpsLoadingChip()
                      : _GpsErrorChip(
                          code: _locationErrCode,
                          onRetry: _initLocation,
                        ),
                ),
              ),

            // ── Top row: Back (left) + Zoom (right) ──────────────────────
            Positioned(
              top: topPadding + 10,
              left: 14,
              right: 14,

              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FloatingBackButton(),
                  const Spacer(),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ZoomControls(mapController: _mapController),
                      const SizedBox(height: 12),
                      _LegendInfoButton(
                        onTap: () => _showLegendDialog(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Locate-me button ─────────────────────────────────────────
            Positioned(
              right: 14,
              bottom: _targetStation != null ? 350 : 100,
              child: _LocateMeButton(onTap: _locateMe),
            ),

            // Removed _DirectionsButton

            // ── Selected Station Details ────────────────────────────────
            if (_targetStation != null)
              Positioned(
                left: 14,
                right: 14,
                bottom: 110,
                child: _StationDetailsCard(
                  station: _targetStation!,
                  onNavigate: _openGoogleMapsDirections,
                  onClose: () => setState(() => _targetStation = null),
                ),
              ),

            // ── Floating Action Buttons (SOS & Info) ────────────────────
            Positioned(
              left: 14,
              bottom: 30,
              child: _SosFloatingButton(onTap: _onSosTapped),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// GPS LOADING CHIP
// =============================================================================
class _GpsLoadingChip extends StatelessWidget {
  const _GpsLoadingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: _MapColors.shadow, blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _MapColors.userDot,
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Đang lấy vị trí GPS...',
            style: TextStyle(
              color: _MapColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// GPS ERROR CHIP  — shows why GPS failed + context-aware action button
// =============================================================================
class _GpsErrorChip extends StatelessWidget {
  final _LocErrCode? code;
  final VoidCallback onRetry;

  const _GpsErrorChip({required this.code, required this.onRetry});

  bool get _needsSettings =>
      code == _LocErrCode.permissionDeniedForever ||
      code == _LocErrCode.unableToDetermine;

  String get _label {
    switch (code) {
      case _LocErrCode.serviceDisabled:
        return 'GPS tắt';
      case _LocErrCode.permissionDenied:
        return 'Chưa cấp quyền';
      case _LocErrCode.permissionDeniedForever:
        return 'Quyền bị từ chối vĩnh viễn';
      case _LocErrCode.unableToDetermine:
        return 'Thiếu khai báo quyền';
      default:
        return 'Không lấy được GPS';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _needsSettings ? Geolocator.openAppSettings : onRetry,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.shade800,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: _MapColors.shadow, blurRadius: 10),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_rounded,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              _label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _needsSettings ? 'Cài đặt' : 'Thử lại',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
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
// MAP LAYER  — StatefulWidget để quản lý state đường đi thực tế
// =============================================================================
class _MapLayer extends ConsumerStatefulWidget {
  final MapController mapController;
  final Animation<double> pulseAnim;
  final LatLng userLocation;
  final void Function(LatLng?, RescueStation?) onRouteTargetChanged;

  const _MapLayer({
    required this.mapController,
    required this.pulseAnim,
    required this.userLocation,
    required this.onRouteTargetChanged,
  });

  @override
  ConsumerState<_MapLayer> createState() => _MapLayerState();
}

class _MapLayerState extends ConsumerState<_MapLayer> {
  // ── Routing state ──────────────────────────────────────────────────────────

  /// Danh sách điểm tọa độ tạo nên đường đi.
  ///
  /// • Khi mới khởi tạo / API đang gọi / API lỗi: rỗng → không vẽ polyline.
  /// • Sau khi API thành công: chứa nhiều điểm theo đường bộ thực tế.
  /// • Sau khi fallback: chứa đúng 2 điểm [user, nearest] — đường chim bay.
  List<LatLng> _routePoints = [];

  /// Trạm đích hiện tại của route (mặc định: gần nhất, hoặc user chọn).
  String? _routeStationId;

  /// Trạm do user chủ động chọn bằng cách tap marker.
  String? _selectedStationId;

  /// Snapshot trạm mới nhất dùng cho retry/fallback mà không cần rebuild.
  List<RescueStation> _latestStations = const [];

  String _stationsFingerprint = '';

  /// true khi đang fetch API (hiện loading indicator nhỏ trên bản đồ).
  bool _routeLoading = false;

  /// true nếu đang dùng fallback đường chim bay (do API lỗi).
  bool _isFallback = false;

  List<CommunityReport> _latestReports = const [];
  String _reportsFingerprint = '';

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    final initial = ref.read(rescueStationsProvider);
    initial.whenData((stations) {
      _latestStations = stations;
      _stationsFingerprint = _fingerprintStations(stations);
      _computeRouteFromProps(widget.userLocation, stations, _latestReports);
    });

    _initCheckInState();
  }

  Future<void> _initCheckInState() async {
    final repo = ref.read(rescueStationRepositoryProvider);
    final latestLog = await repo.getLatestCheckInLog();
    if (latestLog != null && latestLog.type == 'in') {
      ref.read(currentCheckedInStationProvider.notifier).state =
          latestLog.stationId;
    }
  }

  @override
  void didUpdateWidget(_MapLayer old) {
    super.didUpdateWidget(old);

    // Chỉ tính lại đường khi vị trí người dùng thay đổi đáng kể (> 20m)
    // hoặc danh sách trạm thay đổi — tránh gọi API liên tục khi GPS jitter.
    final locationChanged =
        Geolocator.distanceBetween(
          old.userLocation.latitude,
          old.userLocation.longitude,
          widget.userLocation.latitude,
          widget.userLocation.longitude,
        ) >
        20; // mét

    if (locationChanged) {
      _computeRouteFromProps(widget.userLocation, _latestStations, _latestReports);
    }
  }

  // ── Core logic ─────────────────────────────────────────────────────────────

  /// Pipeline chính:
  ///   1. Tìm trạm gần nhất (Geolocator.distanceBetween)
  ///   2. Gọi OpenRouteService.getRoute()
  ///   3. Nếu thành công → cập nhật _routePoints với đường bộ thực tế
  ///   4. Nếu thất bại → fallback về 2 điểm đường chim bay
  Future<void> _computeRouteFromProps(
    LatLng userLoc,
    List<RescueStation> stations,
    List<CommunityReport> reports,
  ) async {
    // ── Bước 1: Chọn trạm đích (ưu tiên trạm user chọn, fallback gần nhất) ──
    final destination = _resolveTargetStation(userLoc, stations);
    if (destination == null) {
      if (!mounted) return;
      setState(() {
        _routeStationId = null;
        _selectedStationId = null;
        _routePoints = const [];
        _routeLoading = false;
        _isFallback = false;
      });
      widget.onRouteTargetChanged(null, null);
      return;
    }

    final destinationPoint = LatLng(
      destination.latitude,
      destination.longitude,
    );

    // Tối ưu hóa: Nếu trạm đích và vị trí bắt đầu/kết thúc không thay đổi đáng kể,
    // ta chỉ cập nhật đối tượng station cho UI mà không cần fetch lại route.
    final bool isSameStation = destination.id == _routeStationId;
    final bool hasExistingRoute = _routePoints.isNotEmpty;
    final bool startValid =
        hasExistingRoute &&
        Geolocator.distanceBetween(
          userLoc.latitude,
          userLoc.longitude,
          _routePoints.first.latitude,
          _routePoints.first.longitude,
        ) <
        20;
    final bool endValid =
        hasExistingRoute &&
        Geolocator.distanceBetween(
          destinationPoint.latitude,
          destinationPoint.longitude,
          _routePoints.last.latitude,
          _routePoints.last.longitude,
        ) <
        5;

    if (isSameStation && startValid && endValid) {
      widget.onRouteTargetChanged(destinationPoint, destination);
      return;
    }

    _routeStationId = destination.id;
    widget.onRouteTargetChanged(destinationPoint, destination);

    // ── Bước 2: Bắt đầu fetch API ──────────────────────────────────────────
    if (!mounted) return;
    setState(() {
      _routeLoading = true;
      _isFallback = false;
      _routePoints = []; // Xoá đường cũ trong khi fetch
    });

    try {
      final points = await OpenRouteService.instance.getRoute(
        userLoc,
        destinationPoint,
        avoidPoints: reports.map((r) => LatLng(r.latitude, r.longitude)).toList(),
      );

      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _routeLoading = false;
        _isFallback = false;
      });

      debugPrint('[MapLayer] Route OK: ${points.length} điểm tọa độ');
    } on RoutingException catch (e) {
      debugPrint('[MapLayer] RoutingException → fallback: $e');
      _fallbackToStraightLine(userLoc, destinationPoint);
    } catch (e) {
      // Bắt SocketException, TimeoutException, FormatException...
      debugPrint('[MapLayer] Lỗi không xác định → fallback: $e');
      _fallbackToStraightLine(userLoc, destinationPoint);
    }
  }

  RescueStation? _resolveTargetStation(
    LatLng userLoc,
    List<RescueStation> stations,
  ) {
    if (stations.isEmpty) return null;

    final checkedInId = ref.read(currentCheckedInStationProvider);
    final selectedId = _selectedStationId ?? checkedInId;
    
    if (selectedId != null) {
      final selected = _findStationById(stations, selectedId);
      if (selected != null) return selected;

      // Trạm đã bị xoá/ẩn khỏi dữ liệu hiện tại, quay về chế độ mặc định.
      if (_selectedStationId != null) {
        _selectedStationId = null;
      }
    }

    return _findNearestStation(userLoc, stations);
  }

  RescueStation? _findStationById(List<RescueStation> stations, String id) {
    for (final station in stations) {
      if (station.id == id) return station;
    }
    return null;
  }

  /// Fallback: vẽ đường chim bay 2 điểm khi API không khả dụng.
  void _fallbackToStraightLine(LatLng from, LatLng to) {
    if (!mounted) return;
    setState(() {
      _routePoints = [from, to]; // 2 điểm = đường thẳng
      _routeLoading = false;
      _isFallback = true;
    });
  }

  // ── Nearest station helper ─────────────────────────────────────────────────

  /// Tìm trạm gần [userLoc] nhất bằng Geolocator.distanceBetween.
  /// Trả về null nếu [stations] rỗng.
  RescueStation? _findNearestStation(
    LatLng userLoc,
    List<RescueStation> stations,
  ) {
    if (stations.isEmpty) return null;

    RescueStation nearest = stations.first;
    double minDist = Geolocator.distanceBetween(
      userLoc.latitude,
      userLoc.longitude,
      nearest.latitude,
      nearest.longitude,
    );

    for (final st in stations.skip(1)) {
      final d = Geolocator.distanceBetween(
        userLoc.latitude,
        userLoc.longitude,
        st.latitude,
        st.longitude,
      );
      if (d < minDist) {
        minDist = d;
        nearest = st;
      }
    }

    return nearest;
  }

  String _fingerprintStations(List<RescueStation> stations) {
    final keys =
        stations
            .map(
              (s) =>
                  '${s.id}:${s.latitude}:${s.longitude}:${s.status}:${s.occupancy}',
            )
            .toList()
          ..sort();
    return keys.join('|');
  }

  void _onStationTapped(RescueStation station) {
    setState(() {
      _selectedStationId = station.id;
    });

    _computeRouteFromProps(widget.userLocation, _latestStations, _latestReports);
  }

  String _fingerprintReports(List<CommunityReport> reports) {
    final keys = reports.map((r) => '${r.id}:${r.latitude}:${r.longitude}').toList()..sort();
    return keys.join('|');
  }

  void _showCommunityReportDialog(LatLng location, {CommunityReport? existingReport}) {
    showDialog(
      context: context,
      builder: (_) => _CommunityReportDialog(
        location: location,
        parentRef: ref,
        existingReport: existingReport,
      ),
    );
  }

  void _showCommunityReportDetailsDialog(CommunityReport report) {
    showDialog(
      context: context,
      builder: (_) => _CommunityReportDetailsDialog(
        report: report,
        parentRef: ref,
        onEdit: () {
          _showCommunityReportDialog(
            LatLng(report.latitude, report.longitude),
            existingReport: report,
          );
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<RescueStation>>>(rescueStationsProvider, (
      previous,
      next,
    ) {
      next.whenData((stations) {
        final nextFingerprint = _fingerprintStations(stations);
        if (nextFingerprint == _stationsFingerprint) return;

        _stationsFingerprint = nextFingerprint;
        _latestStations = stations;
        _computeRouteFromProps(widget.userLocation, stations, _latestReports);
      });
    });

    ref.listen<AsyncValue<List<CommunityReport>>>(communityReportsProvider, (previous, next) {
      next.whenData((reports) {
        final nextFingerprint = _fingerprintReports(reports);
        if (nextFingerprint == _reportsFingerprint) return;

        _reportsFingerprint = nextFingerprint;
        _latestReports = reports;
        _computeRouteFromProps(widget.userLocation, _latestStations, reports);
      });
    });

    ref.listen<String?>(currentCheckedInStationProvider, (previous, next) {
      if (previous != next) {
        if (next != null) {
          _selectedStationId = next;
        }
        _computeRouteFromProps(widget.userLocation, _latestStations, _latestReports);
      }
    });

    final rescueStationsAsync = ref.watch(rescueStationsProvider);
    final rescueStations = rescueStationsAsync.maybeWhen(
      data: (stations) {
        _latestStations = stations;
        return stations;
      },
      orElse: () => _latestStations,
    );

    final reportsAsync = ref.watch(communityReportsProvider);
    final communityReports = reportsAsync.maybeWhen(
      data: (reports) {
        _latestReports = reports;
        return reports;
      },
      orElse: () => _latestReports,
    );

    final hasRoute = _routePoints.length >= 2;

    return Stack(
      children: [
        // ── FlutterMap ───────────────────────────────────────────────────
        FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(
            initialCenter: widget.userLocation,
            initialZoom: 13.5,
            minZoom: 5,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onLongPress: (tapPosition, point) => _showCommunityReportDialog(point),
          ),
          children: [
            // ── 1. Tile layer — OpenStreetMap ──────────────────────────
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.omnidisaster.app',
              tileProvider: NetworkTileProvider(),
            ),

            // ── 2. Polyline layer — TRƯỚC MarkerLayer ──────────────────
            // Đường bộ thực tế (nhiều điểm) khi API thành công,
            // hoặc đường chim bay nét đứt (2 điểm) khi fallback.
            if (hasRoute)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    color: Colors.blue,
                    strokeWidth: 4.0,
                    // Đường bộ thực tế: nét liền mượt hơn
                    // Fallback đường chim bay: nét đứt để phân biệt
                    pattern: StrokePattern.dashed(segments: [18, 12]),
                  ),
                ],
              ),

            // ── 3. Marker layer — SAU PolylineLayer ───────────────────
            MarkerLayer(
              markers: [
                // ── Rescue stations — trạm đích hiện tại highlight to hơn ──
                for (final station in rescueStations)
                  Marker(
                    point: LatLng(station.latitude, station.longitude),
                    width: station.id == _routeStationId ? 64 : 56,
                    height: station.id == _routeStationId ? 64 : 56,
                    child: GestureDetector(
                      onTap: () => _onStationTapped(station),
                      child: _RescueMarker(
                        selected: station.id == _routeStationId,
                        isFull: station.status == 'full',
                      ),
                    ),
                  ),

                // ── Community Reports ──────────────────────────────────────────
                for (final report in communityReports)
                  Marker(
                    point: LatLng(report.latitude, report.longitude),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _showCommunityReportDetailsDialog(report),
                      child: _CommunityReportMarker(report: report),
                    ),
                  ),

                // ── User location (on top) ─────────────────────────────
                Marker(
                  point: widget.userLocation,
                  width: 56,
                  height: 56,
                  child: _UserLocationMarker(pulseAnim: widget.pulseAnim),
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

        // ── Route loading indicator (góc trên phải bản đồ) ──────────────
        if (_routeLoading)
          Positioned(top: 12, right: 12, child: _RouteLoadingChip()),

        // ── Fallback badge (thông báo nhẹ khi đang dùng đường chim bay) ─
        if (_isFallback && !_routeLoading)
          Positioned(
            top: 12,
            right: 12,
            child: _RouteFallbackChip(
              onRetry: () =>
                  _computeRouteFromProps(widget.userLocation, _latestStations, _latestReports),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// ROUTE LOADING CHIP — hiển thị khi đang gọi ORS API
// =============================================================================
class _RouteLoadingChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: _MapColors.shadow, blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.blue,
            ),
          ),
          SizedBox(width: 7),
          Text(
            'Đang tính đường đi...',
            style: TextStyle(
              color: _MapColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ROUTE FALLBACK CHIP — hiển thị khi API lỗi, cho phép retry
// =============================================================================
class _RouteFallbackChip extends StatelessWidget {
  final VoidCallback onRetry;
  const _RouteFallbackChip({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRetry,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.orange.shade700,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: _MapColors.shadow, blurRadius: 8)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.route_outlined, color: Colors.white, size: 13),
            SizedBox(width: 5),
            Text(
              'Đường chim bay · Thử lại',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// MARKERS  (unchanged)
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
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, __) => Container(
              width: 36 * pulseAnim.value,
              height: 36 * pulseAnim.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _MapColors.userDotRing.withOpacity(
                  0.6 * (1 - pulseAnim.value + 0.3),
                ),
              ),
            ),
          ),
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
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
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
        CustomPaint(
          size: const Size(10, 6),
          painter: _PinTailPainter(color: _MapColors.sosRed),
        ),
      ],
    );
  }
}

// ── Rescue Station: Green cross ───────────────────────────────────────────────
class _RescueMarker extends StatelessWidget {
  final bool selected;
  final bool isFull;

  const _RescueMarker({this.selected = false, this.isFull = false});

  @override
  Widget build(BuildContext context) {
    final color = isFull ? Colors.orange.shade700 : _MapColors.rescueGreen;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: selected ? 42 : 38,
          height: selected ? 42 : 38,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(
                  selected ? 0.55 : 0.4,
                ),
                blurRadius: selected ? 14 : 10,
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
          painter: _PinTailPainter(color: color),
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
// FLOATING BACK BUTTON  (unchanged)
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
// ZOOM CONTROLS  (unchanged)
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
            color: _MapColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
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

  const _ZoomBtn({
    required this.icon,
    required this.onTap,
    required this.isTop,
  });

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
// LOCATE-ME BUTTON  (unchanged)
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
// FLOATING ACTION BUTTONS (SOS & INFO)
// =============================================================================
class _SosFloatingButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SosFloatingButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _MapColors.sosRed,
      borderRadius: BorderRadius.circular(16),
      elevation: 6,
      shadowColor: _MapColors.sosRed.withOpacity(0.5),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.sos_rounded, color: Colors.white, size: 28),
              SizedBox(width: 8),
              Text(
                'Phát SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendInfoButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LegendInfoButton({required this.onTap});

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
            Icons.info_outline_rounded,
            size: 24,
            color: _MapColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

// DirectionsButton removed
// _BottomLegendSheet removed

// =============================================================================
// SOS CONFIRM DIALOG  — now a ConsumerStatefulWidget, receives real coords
// =============================================================================
class _SosConfirmDialog extends ConsumerStatefulWidget {
  final BuildContext parentContext;

  /// Tọa độ thật từ geolocator; null nếu chưa lấy được → sẽ thử lại lần nữa.
  final LatLng? currentLocation;

  const _SosConfirmDialog({
    required this.parentContext,
    required this.currentLocation,
  });

  @override
  ConsumerState<_SosConfirmDialog> createState() => _SosConfirmDialogState();
}

class _SosConfirmDialogState extends ConsumerState<_SosConfirmDialog> {
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _MapColors.sosRed.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sos_rounded,
              color: _MapColors.sosRed,
              size: 34,
            ),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _sending
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                  onPressed: _sending ? null : () => _submitSOS(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _MapColors.sosRed,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
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

  Future<void> _submitSOS(BuildContext dialogContext) async {
    setState(() => _sending = true);

    final messenger = ScaffoldMessenger.of(widget.parentContext);

    // ── 1. Resolve coordinates ─────────────────────────────────────────────
    // Parent already has a GPS fix → use it directly.
    // Otherwise try one more _determinePosition() in case the user just
    // granted permission inside the dialog.
    LatLng coords;
    try {
      if (widget.currentLocation != null) {
        coords = widget.currentLocation!;
      } else {
        final pos = await _determinePosition();
        coords = LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {
      // Last resort: never drop the SOS silently.
      coords = _kFallbackLocation;
    }

    // Close dialog before async DB work so UI feels snappy
    Navigator.of(dialogContext).pop();

    final db = ref.read(dbProvider);
    final postId = DateTime.now().millisecondsSinceEpoch.toString();
    final locId = 'loc_$postId';
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // ── 2. Save Post to Drift (offline-first) ──────────────────────────────
    await db
        .into(db.posts)
        .insert(
          PostsCompanion.insert(
            id: postId,
            eventId: 'current_event_id',
            userId: uid,
            postType: 'sos',
            content: 'Tôi đang cần cứu hộ khẩn cấp!',
            createdAt: DateTime.now(),
            syncStatus: const drift.Value('pending'),
          ),
        );

    // ── 3. Save real GPS coordinates to Drift ──────────────────────────────
    await db
        .into(db.locations)
        .insert(
          LocationsCompanion.insert(
            id: locId,
            postId: postId,
            latitude: coords.latitude, // ← real GPS lat
            longitude: coords.longitude, // ← real GPS lng
          ),
        );

    // ── 4. Immediately try to push to Firebase ─────────────────────────────
    final syncService = ref.read(firebaseSyncServiceProvider);
    final result = await syncService.syncPendingSOS();

    // ── 5. Show result snackbar ────────────────────────────────────────────
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              result.isSuccess
                  ? Icons.check_circle_rounded
                  : Icons.cloud_off_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                result.isSuccess
                    ? 'Đã gửi SOS! '
                          '(${coords.latitude.toStringAsFixed(5)}, '
                          '${coords.longitude.toStringAsFixed(5)})'
                    : 'Đã lưu offline. Sẽ gửi khi có mạng!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: result.isSuccess
            ? Colors.green.shade600
            : Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// =============================================================================
// STATION DETAILS CARD
// =============================================================================
class _StationDetailsCard extends ConsumerStatefulWidget {
  final RescueStation station;
  final VoidCallback onNavigate;
  final VoidCallback onClose;

  const _StationDetailsCard({
    required this.station,
    required this.onNavigate,
    required this.onClose,
  });

  @override
  ConsumerState<_StationDetailsCard> createState() =>
      _StationDetailsCardState();
}

class _StationDetailsCardState extends ConsumerState<_StationDetailsCard> {
  bool _isLoading = false;

  Future<void> _handleCheckInOut() async {
    final currentCheckedInId = ref.read(currentCheckedInStationProvider);
    final isCheckedInHere = currentCheckedInId == widget.station.id;

    setState(() => _isLoading = true);
    try {
      if (isCheckedInHere) {
        await ref
            .read(rescueStationControllerProvider.notifier)
            .checkOut(widget.station.id);
        ref.read(currentCheckedInStationProvider.notifier).state = null;
      } else {
        if (currentCheckedInId != null) {
          await ref
              .read(rescueStationControllerProvider.notifier)
              .checkOut(currentCheckedInId);
        }
        await ref
            .read(rescueStationControllerProvider.notifier)
            .checkIn(widget.station.id);
        ref.read(currentCheckedInStationProvider.notifier).state =
            widget.station.id;

        widget.onNavigate();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Luôn lấy dữ liệu mới nhất từ provider để đảm bảo tính thời gian thực (occupancy, status...)
    final stationsAsync = ref.watch(rescueStationsProvider);
    final station = stationsAsync.maybeWhen(
      data: (list) => list.firstWhere(
        (s) => s.id == widget.station.id,
        orElse: () => widget.station,
      ),
      orElse: () => widget.station,
    );

    final currentCheckedInId = ref.watch(currentCheckedInStationProvider);
    final isCheckedInHere = currentCheckedInId == station.id;

    final isFull = station.status == 'full';
    final canCheckIn = !isFull || isCheckedInHere;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: _MapColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _MapColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sức chứa: ${station.occupancy}/${station.capacity?.toString() ?? "∞"}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: _MapColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isFull
                      ? Colors.orange.shade100
                      : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isFull ? 'Đã đầy' : 'Còn chỗ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isFull
                        ? Colors.orange.shade800
                        : Colors.green.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: widget.onClose,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: _MapColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!isFull || isCheckedInHere)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleCheckInOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCheckedInHere
                      ? Colors.grey.shade400
                      : _MapColors.rescueGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isCheckedInHere ? 'Rời khỏi trạm' : 'Đến trạm này',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
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
// COMMUNITY REPORT MARKER
// =============================================================================
class _CommunityReportMarker extends StatelessWidget {
  final CommunityReport report;

  const _CommunityReportMarker({required this.report});

  @override
  Widget build(BuildContext context) {
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

    return Column(
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
    );
  }
}

// =============================================================================
// COMMUNITY REPORT DIALOG
// =============================================================================
class _CommunityReportDialog extends StatefulWidget {
  final LatLng location;
  final WidgetRef parentRef;
  final CommunityReport? existingReport;

  const _CommunityReportDialog({
    required this.location,
    required this.parentRef,
    this.existingReport,
  });

  @override
  State<_CommunityReportDialog> createState() => _CommunityReportDialogState();
}

class _CommunityReportDialogState extends State<_CommunityReportDialog> {
  String _selectedType = 'fallen_tree';
  final _customTypeController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingReport != null) {
      final report = widget.existingReport!;
      final types = ['fallen_tree', 'flood', 'road_block', 'other'];
      if (types.contains(report.type)) {
        _selectedType = report.type;
      } else {
        _selectedType = 'other';
      }
      _customTypeController.text = report.customTypeName ?? '';
      _descriptionController.text = report.description ?? '';
    }
  }

  @override
  void dispose() {
    _customTypeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedType == 'other' && _customTypeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên loại sự cố khác.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final controller = widget.parentRef.read(communityReportControllerProvider);
      
      if (widget.existingReport != null) {
        await controller.updateReport(
          reportId: widget.existingReport!.id,
          type: _selectedType,
          customTypeName: _selectedType == 'other' ? _customTypeController.text.trim() : null,
          description: _descriptionController.text.trim(),
        );
      } else {
        await controller.addReport(
          latitude: widget.location.latitude,
          longitude: widget.location.longitude,
          type: _selectedType,
          customTypeName: _selectedType == 'other' ? _customTypeController.text.trim() : null,
          description: _descriptionController.text.trim(),
        );
      }
      
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existingReport != null ? 'Cập nhật thành công!' : 'Cảm ơn bạn! Báo cáo sự cố đã được ghi nhận.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: const [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          SizedBox(width: 8),
          Text(
            'Báo cáo sự cố',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Loại sự cố:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'fallen_tree', child: Text('Cây đổ')),
                DropdownMenuItem(value: 'flood', child: Text('Ngập sâu')),
                DropdownMenuItem(value: 'road_block', child: Text('Tắc đường / Sạt lở')),
                DropdownMenuItem(value: 'other', child: Text('Khác...')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedType = val);
              },
            ),
            if (_selectedType == 'other') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customTypeController,
                decoration: InputDecoration(
                  labelText: 'Tên sự cố',
                  hintText: 'Vd: Sập cầu, Cháy nhà...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Mô tả thêm (Tùy chọn):',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Nhập thông tin chi tiết...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(widget.existingReport != null ? 'Cập nhật' : 'Báo cáo', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// =============================================================================
// COMMUNITY REPORT DETAILS DIALOG
// =============================================================================
class _CommunityReportDetailsDialog extends StatefulWidget {
  final CommunityReport report;
  final WidgetRef parentRef;
  final VoidCallback onEdit;

  const _CommunityReportDetailsDialog({
    required this.report,
    required this.parentRef,
    required this.onEdit,
  });

  @override
  State<_CommunityReportDetailsDialog> createState() => _CommunityReportDetailsDialogState();
}

class _CommunityReportDetailsDialogState extends State<_CommunityReportDetailsDialog> {
  bool _isDeleting = false;

  Future<void> _deleteReport() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa báo cáo này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      final controller = widget.parentRef.read(communityReportControllerProvider);
      await controller.deleteReport(widget.report.id);
      
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa báo cáo.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xóa: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser != null && widget.report.reportedBy == currentUser.uid;

    IconData icon;
    String typeLabel;
    switch (widget.report.type) {
      case 'fallen_tree':
        icon = Icons.park_rounded;
        typeLabel = 'Cây đổ';
        break;
      case 'flood':
        icon = Icons.water_drop_rounded;
        typeLabel = 'Ngập sâu';
        break;
      case 'road_block':
        icon = Icons.remove_road_rounded;
        typeLabel = 'Tắc đường / Sạt lở';
        break;
      default:
        icon = Icons.warning_rounded;
        typeLabel = widget.report.customTypeName ?? 'Khác';
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.orange.shade700, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              typeLabel,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.report.description?.isNotEmpty == true) ...[
              const Text(
                'Mô tả:',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                widget.report.description!,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Người báo cáo:',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(isOwner ? 'Bạn' : 'Cộng đồng'),
          ],
        ),
      ),
      actions: [
        if (isOwner) ...[
          TextButton(
            onPressed: _isDeleting ? null : _deleteReport,
            child: _isDeleting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: _isDeleting ? null : () {
              Navigator.of(context).pop();
              widget.onEdit();
            },
            child: const Text('Sửa', style: TextStyle(color: Colors.blue)),
          ),
        ],
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
          child: Text(isOwner ? 'Đóng' : 'OK', style: const TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
