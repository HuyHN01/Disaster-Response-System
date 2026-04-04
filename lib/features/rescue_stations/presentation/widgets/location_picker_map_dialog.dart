// lib/features/rescue_stations/presentation/widgets/location_picker_map_dialog.dart

import 'dart:async';

import 'package:disaster_response_app/core/services/routing/open_route_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'location_autocomplete_field.dart';

class LocationPickerMapDialog extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerMapDialog({super.key, this.initialLocation});

  @override
  State<LocationPickerMapDialog> createState() =>
      _LocationPickerMapDialogState();
}

class _LocationPickerMapDialogState extends State<LocationPickerMapDialog> {
  late final MapController _mapCtrl;
  late LatLng _currentCenter;
  
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loadingLocation = false;
  String _addressPreview = 'Đang tải địa chỉ...';

  Timer? _mapDebounceTimer;

  // Fallback map location
  static const LatLng _kFallbackLocation = LatLng(21.0285, 105.8542); // Hà Nội

  @override
  void initState() {
    super.initState();
    _mapCtrl = MapController();
    _currentCenter = widget.initialLocation ?? _kFallbackLocation;

    if (widget.initialLocation == null) {
      _getCurrentLocation();
    } else {
      _reverseGeocodeCenter();
    }
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    _searchCtrl.dispose();
    _mapDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _loadingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS is disabled.');

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        
        final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ));
        
        final latLng = LatLng(pos.latitude, pos.longitude);
        setState(() => _currentCenter = latLng);
        _mapCtrl.move(latLng, 14.0);
        await _reverseGeocodeCenter();
      }
    } catch (e) {
      debugPrint('[MAP PICKER] Location Error: $e');
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _reverseGeocodeCenter() async {
    setState(() => _addressPreview = 'Đang tìm...');
    final result = await OpenRouteService.instance.reverseGeocode(_currentCenter);
    if (!mounted) return;

    if (result != null) {
      setState(() {
         _addressPreview = result.toString();
         _searchCtrl.text = _addressPreview;
      });
    } else {
      setState(() => _addressPreview = 'Không xác định được địa chỉ');
    }
  }

  void _onSearchSelected(LocationResult result) {
    final latLng = LatLng(result.latitude, result.longitude);
    _mapCtrl.move(latLng, 15.0);
    setState(() {
       _currentCenter = latLng;
       _addressPreview = result.toString();
    });
  }

  void _onConfirm() {
    Navigator.of(context).pop(
      LocationResult(
        name: '', // We mostly care about address + coords
        address: _addressPreview,
        latitude: _currentCenter.latitude,
        longitude: _currentCenter.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 800,
        height: 600,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.map_outlined),
                  const SizedBox(width: 8),
                  const Text(
                    'Chọn vị trí trên bản đồ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
            ),
            
            // Search Bar over Map
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: LocationAutocompleteField(
                      controller: _searchCtrl,
                      onSelected: _onSearchSelected,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _loadingLocation ? null : _getCurrentLocation,
                    tooltip: 'Đến vị trí hiện tại của tôi',
                    icon: _loadingLocation
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location_rounded),
                  ),
                ],
              ),
            ),

            // Map Area
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapCtrl,
                    options: MapOptions(
                      initialCenter: _currentCenter,
                      initialZoom: 14.0,
                      onPositionChanged: (pos, hasGesture) {
                        if (hasGesture && pos.center != null) {
                          setState(() {
                             _currentCenter = pos.center!;
                             _addressPreview = 'Đang kéo thả...';
                          });
                          
                          _mapDebounceTimer?.cancel();
                          _mapDebounceTimer = Timer(const Duration(milliseconds: 800), () {
                            if (mounted) {
                              _reverseGeocodeCenter();
                            }
                          });
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        // Sử dụng OpenStreetMap public. 
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.omnidisaster.app',
                      ),
                    ],
                  ),
                  
                  // Center Pin Marker
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 40), // Căn cho đỉnh pin chạm đúng giữa
                      child: Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Tọa độ hiện tại:',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        Text('${_currentCenter.latitude.toStringAsFixed(6)}, ${_currentCenter.longitude.toStringAsFixed(6)}',
                             style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        const SizedBox(height: 4),
                        Text(_addressPreview, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _addressPreview == 'Đang tìm...' || _addressPreview.isEmpty 
                      ? null 
                      : _onConfirm,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Chọn vị trí này'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
