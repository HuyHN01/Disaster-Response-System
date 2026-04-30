// lib/core/services/routing/open_route_service.dart
//
// OpenRouteService — Định tuyến đường bộ thực tế
// ─────────────────────────────────────────────────────────────────────────────
// API sử dụng: https://openrouteservice.org/dev/#/api-docs
// Endpoint:    GET /v2/directions/driving-car  (trả về GeoJSON)
//
// ⚠️  QUAN TRỌNG VỀ FORMAT:
//   Endpoint GET với query params ?start=&end= trả về GeoJSON LineString:
//     features[0].geometry.coordinates = [[lng, lat], [lng, lat], ...]
//   Đây KHÔNG phải encoded polyline của Google Maps.
//   → Không dùng PolylinePoints().decodePolyline() cho endpoint này.
//   → Parse coordinates trực tiếp từ JSON (xem _parseGeoJsonCoordinates).
//
//   Nếu muốn dùng PolylinePoints, chuyển sang endpoint POST /v2/directions
//   với body JSON và thêm header 'Accept: application/json' — khi đó
//   geometry trả về dạng encoded string. Xem comment ở cuối file.
//
// ⚠️  API KEY:
//   Đăng ký miễn phí tại https://openrouteservice.org/dev/#/signup
//   Thay chuỗi 'YOUR_ORS_API_KEY' bên dưới bằng key thật của bạn.
//   KHÔNG commit key vào git — dùng --dart-define hoặc .env.
//
// Dependencies (pubspec.yaml):
//   http: ^1.x.x
//   latlong2: ^0.9.x   (đã có qua flutter_map)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// =============================================================================
// EXCEPTIONS & MODELS
// =============================================================================

/// Lỗi trả về từ OpenRouteService (bao gồm lỗi mạng lẫn lỗi API).
class RoutingException implements Exception {
  final String message;
  final int? statusCode;

  const RoutingException(this.message, {this.statusCode});

  @override
  String toString() => 'RoutingException[$statusCode]: $message';
}

/// Chứa kết quả từ Geocoding API.
class LocationResult {
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const LocationResult({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  @override
  String toString() {
    if (name.isNotEmpty && address.isNotEmpty && name != address) {
      if (address.startsWith(name)) {
         return address;
      }
      return '$name, $address';
    }
    return name.isNotEmpty ? name : address;
  }
}

// =============================================================================
// SERVICE
// =============================================================================

/// Singleton service gọi OpenRouteService API để lấy đường đi thực tế.
///
/// Sử dụng:
/// ```dart
/// final points = await OpenRouteService.instance.getRoute(start, end);
/// ```
class OpenRouteService {
  OpenRouteService._();
  static final OpenRouteService instance = OpenRouteService._();

  // ── Config ──────────────────────────────────────────────────────────────────
  // Đăng ký key tại: https://openrouteservice.org/dev/#/signup
  // Free tier: 2,000 requests/day, 40 requests/minute
  static final String _apiKey = dotenv.env['ORS_API_KEY'] ?? '';

  static const String _baseUrl =
      'https://api.openrouteservice.org/v2/directions/driving-car/geojson';

  static const String _geocodeSearchUrl = 
      'https://api.openrouteservice.org/geocode/search';
  static const String _geocodeReverseUrl = 
      'https://api.openrouteservice.org/geocode/reverse';

  // Timeout tổng cho mỗi request (bao gồm cả thời gian kết nối + đọc data)
  static const Duration _timeout = Duration(seconds: 10);

  // HTTP client — có thể inject mock cho unit test
  final http.Client _client = http.Client();

  // ==========================================================================
  // PUBLIC
  // ==========================================================================

  /// Lấy danh sách điểm tọa độ đường bộ từ [start] đến [end].
  ///
  /// Trả về `List<LatLng>` với ít nhất 2 điểm nếu thành công.
  ///
  /// Ném [RoutingException] nếu:
  ///   - Không có mạng (SocketException / TimeoutException)
  ///   - API trả về status code != 200
  ///   - JSON thiếu field cần thiết
  ///
  /// Caller phải bọc trong try-catch và fallback về đường chim bay nếu cần.
  Future<List<LatLng>> getRoute(LatLng start, LatLng end, {List<LatLng>? avoidPoints}) async {
    final uri = Uri.parse(_baseUrl);

    debugPrint('[ORS] POST $uri');

    final Map<String, dynamic> requestBody = {
      "coordinates": [
        [start.longitude, start.latitude],
        [end.longitude, end.latitude]
      ]
    };

    if (avoidPoints != null && avoidPoints.isNotEmpty) {
      final polygons = avoidPoints.map((p) {
        const offset = 0.00015; // approx 15m
        return [
          [
            [p.longitude - offset, p.latitude - offset],
            [p.longitude + offset, p.latitude - offset],
            [p.longitude + offset, p.latitude + offset],
            [p.longitude - offset, p.latitude + offset],
            [p.longitude - offset, p.latitude - offset],
          ]
        ];
      }).toList();

      requestBody["options"] = {
        "avoid_polygons": {
          "type": "MultiPolygon",
          "coordinates": polygons
        }
      };
    }

    final response = await _client
        .post(
          uri,
          headers: {
            'Authorization': _apiKey,
            'Content-Type': 'application/json',
            'Accept': 'application/json, application/geo+json'
          },
          body: jsonEncode(requestBody),
        )
        .timeout(
          _timeout,
          onTimeout: () => throw const RoutingException(
            'Request timeout sau 10 giây. Kiểm tra kết nối mạng.',
          ),
        );

    debugPrint('[ORS] Response ${response.statusCode} '
        '(${response.body.length} bytes)');

    if (response.statusCode != 200) {
      // Cố parse error message từ body ORS nếu có
      String detail = '';
      try {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        detail = err['error']?['message'] as String? ??
            err['message'] as String? ??
            '';
      } catch (_) {}

      throw RoutingException(
        detail.isNotEmpty
            ? detail
            : 'HTTP ${response.statusCode} từ OpenRouteService',
        statusCode: response.statusCode,
      );
    }

    return _parseGeoJsonResponse(response.body);
  }

  /// Tìm kiếm địa điểm dựa trên từ khóa (Forward Geocoding).
  Future<List<LocationResult>> searchAddress(String query) async {
    if (query.trim().isEmpty) return [];

    // Focus tìm kiếm ở Việt Nam bằng cách dùng boundary (nếu cần thiết) 
    // Tuy nhiên, thêm tham số focus hay text cũng được
    final uri = Uri.parse(
        '$_geocodeSearchUrl?api_key=$_apiKey&text=${Uri.encodeComponent(query.trim())}');

    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode == 200) {
        return _parseGeocodeResponse(response.body);
      }
      return [];
    } catch (e) {
      debugPrint('[ORS] Lỗi searchAddress: $e');
      return [];
    }
  }

  /// Phân giải địa chỉ từ tọa độ (Reverse Geocoding).
  Future<LocationResult?> reverseGeocode(LatLng point) async {
    final uri = Uri.parse(
        '$_geocodeReverseUrl?api_key=$_apiKey&point.lon=${point.longitude}&point.lat=${point.latitude}');

    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode == 200) {
        final results = _parseGeocodeResponse(response.body);
        if (results.isNotEmpty) return results.first;
      }
      return null;
    } catch (e) {
      debugPrint('[ORS] Lỗi reverseGeocode: $e');
      return null;
    }
  }

  // ==========================================================================
  // PRIVATE — PARSING
  // ==========================================================================

  /// Parse GeoJSON LineString trả về từ endpoint GET /v2/directions.
  ///
  /// Cấu trúc JSON ORS trả về:
  /// ```json
  /// {
  ///   "type": "FeatureCollection",
  ///   "features": [{
  ///     "type": "Feature",
  ///     "geometry": {
  ///       "type": "LineString",
  ///       "coordinates": [
  ///         [108.2068, 21.0285],   ← [longitude, latitude]
  ///         [108.2100, 21.0310],
  ///         ...
  ///       ]
  ///     },
  ///     "properties": { "summary": {...}, ... }
  ///   }]
  /// }
  /// ```
  List<LatLng> _parseGeoJsonResponse(String body) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      throw RoutingException('JSON không hợp lệ: $e');
    }

    // Lấy feature đầu tiên
    final features = json['features'];
    if (features is! List || features.isEmpty) {
      throw const RoutingException(
          'Phản hồi ORS không có features. Kiểm tra API key.');
    }

    final feature = features[0] as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>?;

    if (geometry == null) {
      throw const RoutingException('Feature không có geometry.');
    }

    if (geometry['type'] != 'LineString') {
      throw RoutingException(
          'Geometry type không hỗ trợ: ${geometry['type']}');
    }

    final rawCoords = geometry['coordinates'];
    if (rawCoords is! List || rawCoords.isEmpty) {
      throw const RoutingException('coordinates rỗng hoặc không hợp lệ.');
    }

    // Chuyển [[lng, lat], ...] → List<LatLng>
    // ORS trả về longitude TRƯỚC latitude — phải đảo lại!
    return rawCoords.map<LatLng>((coord) {
      if (coord is! List || coord.length < 2) {
        throw const RoutingException('Coordinate point không hợp lệ.');
      }
      final lng = (coord[0] as num).toDouble();
      final lat = (coord[1] as num).toDouble();
      return LatLng(lat, lng); // latlong2: LatLng(lat, lng)
    }).toList();
  }

  /// Parse dữ liệu Geocoding từ JSON của OpenRouteService
  List<LocationResult> _parseGeocodeResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final features = json['features'] as List?;
      if (features == null || features.isEmpty) return [];

      return features.map((f) {
        if (f is! Map<String, dynamic>) return null;
        
        final props = f['properties'] as Map<String, dynamic>? ?? {};
        final geom = f['geometry'] as Map<String, dynamic>? ?? {};
        final coords = geom['coordinates'] as List?;

        if (coords == null || coords.length < 2) return null;

        final name = props['name']?.toString() ?? '';
        final label = props['label']?.toString() ?? '';

        return LocationResult(
          name: name,
          address: label.replaceAll(RegExp('^$name, '), ''),
          longitude: (coords[0] as num).toDouble(),
          latitude: (coords[1] as num).toDouble(),
        );
      }).whereType<LocationResult>().toList();
    } catch (e) {
      debugPrint('[ORS] Lỗi parse _parseGeocodeResponse: $e');
      return [];
    }
  }
}

// =============================================================================
// GHI CHÚ — Nếu muốn dùng PolylinePoints (encoded polyline)
// =============================================================================
//
// Endpoint POST của ORS trả về encoded polyline (Google format):
//
// POST https://api.openrouteservice.org/v2/directions/driving-car
// Headers: { 'Authorization': apiKey, 'Content-Type': 'application/json' }
// Body: { "coordinates": [[startLng, startLat], [endLng, endLat]] }
//
// Response:
// {
//   "routes": [{
//     "geometry": "encodedPolylineString...",   ← Google encoded format
//     ...
//   }]
// }
//
// Lúc đó dùng:
// import 'package:flutter_polyline_points/flutter_polyline_points.dart';
//
// final encoded = routes[0]['geometry'] as String;
// final points  = PolylinePoints().decodePolyline(encoded);
// final latLngs = points.map((p) => LatLng(p.latitude, p.longitude)).toList();