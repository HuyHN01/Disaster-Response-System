// lib/features/event_map/presentation/event_map_screen.dart

import 'dart:ui' as ui;

import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/core/database/db_provider.dart';
import 'package:disaster_response_app/core/services/firebase/sync_service.dart';
import 'package:disaster_response_app/core/services/routing/open_route_service.dart';
import 'package:disaster_response_app/features/event_map/domain/event_map_controller.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

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
                sosLocation: _mockSosLocation(effectiveLocation),
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
                  _ZoomControls(mapController: _mapController),
                ],
              ),
            ),

            // ── Locate-me button ─────────────────────────────────────────
            Positioned(
              right: 14,
              bottom: _legendExpanded ? 272 : 148,
              child: _LocateMeButton(onTap: _locateMe),
            ),

            // ── Bottom Legend + SOS Sheet ────────────────────────────────
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
  final LatLng sosLocation;

  const _MapLayer({
    required this.mapController,
    required this.pulseAnim,
    required this.userLocation,
    required this.sosLocation,
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

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    final initial = ref.read(rescueStationsProvider);
    initial.whenData((stations) {
      _latestStations = stations;
      _stationsFingerprint = _fingerprintStations(stations);
      _computeRouteFromProps(widget.userLocation, stations);
    });
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
      _computeRouteFromProps(widget.userLocation, _latestStations);
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
      return;
    }

    final destinationPoint = LatLng(destination.latitude, destination.longitude);
    _routeStationId = destination.id;

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

    final selectedId = _selectedStationId;
    if (selectedId != null) {
      final selected = _findStationById(stations, selectedId);
      if (selected != null) return selected;

      // Trạm đã bị xoá/ẩn khỏi dữ liệu hiện tại, quay về chế độ mặc định.
      _selectedStationId = null;
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
            .map((s) => '${s.id}:${s.latitude}:${s.longitude}:${s.status}')
            .toList()
          ..sort();
    return keys.join('|');
  }

  void _onStationTapped(RescueStation station) {
    if (_selectedStationId == station.id) return;

    setState(() {
      _selectedStationId = station.id;
    });

    _computeRouteFromProps(widget.userLocation, _latestStations);
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
        _computeRouteFromProps(widget.userLocation, stations);
      });
    });

    final rescueStationsAsync = ref.watch(rescueStationsProvider);
    final rescueStations = rescueStationsAsync.maybeWhen(
      data: (stations) {
        _latestStations = stations;
        return stations;
      },
      orElse: () => _latestStations,
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
                // ── Mock SOS signal ────────────────────────────────────
                Marker(
                  point: widget.sosLocation,
                  width: 56,
                  height: 56,
                  child: _SosMarker(),
                ),

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
                      ),
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
                  _computeRouteFromProps(widget.userLocation, _latestStations),
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

  const _RescueMarker({this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: selected ? 42 : 38,
          height: selected ? 42 : 38,
          decoration: BoxDecoration(
            color: _MapColors.rescueGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _MapColors.rescueGreen.withOpacity(selected ? 0.55 : 0.4),
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
// BOTTOM LEGEND SHEET  (unchanged)
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
                      const Icon(
                        Icons.layers_rounded,
                        size: 18,
                        color: _MapColors.textSecondary,
                      ),
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
                        child: const Icon(
                          Icons.expand_less_rounded,
                          size: 22,
                          color: _MapColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
                icon: const Icon(
                  Icons.sos_rounded,
                  color: Colors.white,
                  size: 22,
                ),
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
            customWidget ?? Icon(icon, color: color, size: 18),
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

    // ── 2. Save Post to Drift (offline-first) ──────────────────────────────
    await db
        .into(db.posts)
        .insert(
          PostsCompanion.insert(
            id: postId,
            eventId: 'current_event_id',
            userId: 'citizen_01',
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
