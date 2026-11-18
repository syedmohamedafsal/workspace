import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import 'geo_distance_calculator.dart';
import 'location_models.dart';
import 'location_service.dart';

/// 1x1 transparent PNG used as a silent fallback tile when completely offline
/// so the clean map canvas below stays visible without red error boxes.
final Uint8List _kTransparentTileBytes = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

/// Real interactive street map view centered on the configured office location,
/// displaying:
/// - Real CartoDB Voyager retina street map tiles (zero API key required)
/// - Pinned office location marker (e.g. Teqbae Innovations, Kochi)
/// - True metric 200m geofence circle surrounding the office
/// - User's live GPS or simulated location pin with connecting distance vector
/// - Zoom (+/-), re-center, tap-to-pin, and one-tap Full-Screen Map expansion
class OfficeGeofenceMap extends StatefulWidget {
  const OfficeGeofenceMap({
    super.key,
    required this.officeName,
    required this.officeLatitude,
    required this.officeLongitude,
    required this.locationService,
    this.allowedRadiusMeters = 200.0,
    this.height = 206,
    this.isFullScreen = false,
    this.enableNetworkTiles,
  });

  final String officeName;
  final double officeLatitude;
  final double officeLongitude;
  final LocationService locationService;
  final double allowedRadiusMeters;
  final double height;
  final bool isFullScreen;
  final bool? enableNetworkTiles;

  @override
  State<OfficeGeofenceMap> createState() => _OfficeGeofenceMapState();
}

class _OfficeGeofenceMapState extends State<OfficeGeofenceMap> {
  final MapController _mapController = MapController();
  late final NetworkTileProvider _tileProvider;
  StreamSubscription<LocationSimulationState>? _simSub;

  late LocationSimulationState _simulation;
  LatLng? _liveUserPoint;
  bool _isResolvingLiveGps = false;
  String? _liveGpsNote;
  bool _mapReady = false;

  LatLng get _officePoint =>
      LatLng(widget.officeLatitude, widget.officeLongitude);

  double get _defaultZoom => widget.isFullScreen ? 16.4 : 15.6;

  bool get _isRunningInWidgetTest {
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    return bindingName.contains('Test');
  }

  bool get _shouldLoadNetworkTiles =>
      widget.enableNetworkTiles ?? !_isRunningInWidgetTest;

  @override
  void initState() {
    super.initState();
    _tileProvider = NetworkTileProvider(
      silenceExceptions: true,
      cachingProvider: const DisabledMapCachingProvider(),
    );
    _simulation = widget.locationService.simulationState;
    _simSub = widget.locationService.simulationStream.listen((next) {
      if (!mounted) return;
      setState(() {
        _simulation = next;
      });
      if (next.mode == LocationSimulationMode.liveGps) {
        _resolveLiveGps();
      } else {
        _refocusCamera();
      }
    });

    if (_simulation.mode == LocationSimulationMode.liveGps &&
        !_isRunningInWidgetTest) {
      _resolveLiveGps();
    }
  }

  @override
  void didUpdateWidget(covariant OfficeGeofenceMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.officeLatitude != widget.officeLatitude ||
        oldWidget.officeLongitude != widget.officeLongitude) {
      _refocusCamera();
    }
  }

  @override
  void dispose() {
    _simSub?.cancel();
    _tileProvider.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _resolveLiveGps() async {
    if (_isResolvingLiveGps) return;
    setState(() {
      _isResolvingLiveGps = true;
      _liveGpsNote = null;
    });

    final result = await widget.locationService.getCurrentLocation(
      officeLatitude: widget.officeLatitude,
      officeLongitude: widget.officeLongitude,
    );

    if (!mounted) return;
    result.fold(
      onSuccess: (coord) {
        setState(() {
          _isResolvingLiveGps = false;
          _liveUserPoint = LatLng(coord.latitude, coord.longitude);
          _liveGpsNote = null;
        });
        _refocusCamera();
      },
      onFailure: (failure) {
        setState(() {
          _isResolvingLiveGps = false;
          _liveUserPoint = null;
          _liveGpsNote = failure.message;
        });
      },
    );
  }

  LatLng? get _activeUserPoint {
    switch (_simulation.mode) {
      case LocationSimulationMode.insideOffice:
        final p = GeoDistanceCalculator.offsetNorth(
          latitude: widget.officeLatitude,
          longitude: widget.officeLongitude,
          northMeters: 25,
        );
        return LatLng(p.latitude, p.longitude);
      case LocationSimulationMode.outsideOffice:
        final p = GeoDistanceCalculator.offsetNorth(
          latitude: widget.officeLatitude,
          longitude: widget.officeLongitude,
          northMeters: 450,
        );
        return LatLng(p.latitude, p.longitude);
      case LocationSimulationMode.custom:
        final lat = _simulation.customLatitude;
        final lng = _simulation.customLongitude;
        if (lat == null || lng == null) return null;
        return LatLng(lat, lng);
      case LocationSimulationMode.liveGps:
        return _liveUserPoint;
      case LocationSimulationMode.permissionDenied:
      case LocationSimulationMode.permissionPermanentlyDenied:
      case LocationSimulationMode.locationUnavailable:
        return null;
    }
  }

  double? get _distanceMeters {
    final user = _activeUserPoint;
    if (user == null) return null;
    return GeoDistanceCalculator.distanceInMeters(
      startLatitude: user.latitude,
      startLongitude: user.longitude,
      endLatitude: widget.officeLatitude,
      endLongitude: widget.officeLongitude,
    );
  }

  bool? get _isInsideRange {
    final dist = _distanceMeters;
    if (dist == null) return null;
    return dist <= widget.allowedRadiusMeters;
  }

  LatLng _offsetEast(LatLng origin, double eastMeters) {
    final metersPerDegreeLon =
        111320.0 * math.cos(origin.latitude * math.pi / 180.0);
    return LatLng(
      origin.latitude,
      origin.longitude + (eastMeters / metersPerDegreeLon),
    );
  }

  void _refocusCamera({bool forceOfficeCenter = false}) {
    if (!_mapReady) return;
    final user = _activeUserPoint;
    final dist = _distanceMeters;

    if (forceOfficeCenter ||
        user == null ||
        dist == null ||
        dist <= widget.allowedRadiusMeters ||
        dist > 2500) {
      _mapController.move(_officePoint, _defaultZoom);
      return;
    }

    final northEdge = GeoDistanceCalculator.offsetNorth(
      latitude: widget.officeLatitude,
      longitude: widget.officeLongitude,
      northMeters: widget.allowedRadiusMeters,
    );
    final southEdge = GeoDistanceCalculator.offsetNorth(
      latitude: widget.officeLatitude,
      longitude: widget.officeLongitude,
      northMeters: -widget.allowedRadiusMeters,
    );
    final eastEdge = _offsetEast(_officePoint, widget.allowedRadiusMeters);
    final westEdge = _offsetEast(_officePoint, -widget.allowedRadiusMeters);

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: [
          _officePoint,
          user,
          LatLng(northEdge.latitude, northEdge.longitude),
          LatLng(southEdge.latitude, southEdge.longitude),
          eastEdge,
          westEdge,
        ],
        padding: widget.isFullScreen
            ? const EdgeInsets.fromLTRB(48, 88, 48, 88)
            : const EdgeInsets.fromLTRB(34, 42, 34, 34),
        maxZoom: _defaultZoom,
      ),
    );
  }

  void _zoomBy(double delta) {
    if (!_mapReady) return;
    final current = _mapController.camera;
    final targetZoom = (current.zoom + delta).clamp(11.0, 19.0);
    _mapController.move(current.center, targetZoom);
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()}m';
  }

  String _shortOfficeLabel(String name) {
    final comma = name.indexOf(',');
    final primary = comma > 0 ? name.substring(0, comma).trim() : name.trim();
    if (primary.length <= 18) return primary;
    return '${primary.substring(0, 17)}…';
  }

  void _handleMapTap(TapPosition tapPosition, LatLng tapped) {
    widget.locationService.updateSimulation(
      LocationSimulationState(
        mode: LocationSimulationMode.custom,
        customLatitude: tapped.latitude,
        customLongitude: tapped.longitude,
      ),
    );
  }

  void _openFullScreenMap() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullScreenOfficeMapPage(
          officeName: widget.officeName,
          officeLatitude: widget.officeLatitude,
          officeLongitude: widget.officeLongitude,
          allowedRadiusMeters: widget.allowedRadiusMeters,
          locationService: widget.locationService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userPoint = _activeUserPoint;
    final dist = _distanceMeters;
    final isInside = _isInsideRange;

    final (statusDot, statusText) = switch (_simulation.mode) {
      LocationSimulationMode.permissionDenied => (
          const Color(0xFFF59E0B),
          'Permission denied',
        ),
      LocationSimulationMode.permissionPermanentlyDenied => (
          const Color(0xFFEF4444),
          'Permission blocked',
        ),
      LocationSimulationMode.locationUnavailable => (
          const Color(0xFFF59E0B),
          'GPS unavailable',
        ),
      _ when dist != null && isInside == true => (
          const Color(0xFF10B981),
          '${_formatDistance(dist)} • Inside ${widget.allowedRadiusMeters.round()}m',
        ),
      _ when dist != null && isInside == false => (
          const Color(0xFFF59E0B),
          '${_formatDistance(dist)} • Outside ${widget.allowedRadiusMeters.round()}m',
        ),
      LocationSimulationMode.liveGps when _isResolvingLiveGps => (
          const Color(0xFF38BDF8),
          'Locating GPS...',
        ),
      LocationSimulationMode.liveGps when _liveGpsNote != null => (
          const Color(0xFFF59E0B),
          'GPS unavailable • Tap map',
        ),
      _ => (
          const Color(0xFF38BDF8),
          '${widget.allowedRadiusMeters.round()}m Office Zone',
        ),
    };

    final zoneColor = isInside == false
        ? const Color(0xFFD97706)
        : const Color(0xFF059669);

    final radiusTagPoint = _offsetEast(_officePoint, widget.allowedRadiusMeters);
    final showConnectorLine =
        userPoint != null && dist != null && dist > 3 && dist <= 5000;

    final mapContent = ClipRRect(
      borderRadius: BorderRadius.circular(widget.isFullScreen ? 0 : 13),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Clean cartographic canvas while real street tiles load or when offline
          const ColoredBox(
            color: Color(0xFFE9EFF5),
            child: CustomPaint(
              painter: _LightMapGridPainter(),
            ),
          ),
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _officePoint,
              initialZoom: _defaultZoom,
              minZoom: 11.0,
              maxZoom: 19.0,
              backgroundColor: Colors.transparent,
              interactionOptions: InteractionOptions(
                // Full drag + pinch in full-screen; pinch/double-tap in embedded
                // card so horizontal swipe between Clock and Map stays smooth.
                flags: widget.isFullScreen
                    ? InteractiveFlag.all & ~InteractiveFlag.rotate
                    : InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
              ),
              onMapReady: () {
                _mapReady = true;
                _refocusCamera();
              },
              onTap: _handleMapTap,
            ),
            children: [
              if (_shouldLoadNetworkTiles)
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  retinaMode: RetinaMode.isHighDensity(context),
                  userAgentPackageName: 'com.rebs.app',
                  tileProvider: _tileProvider,
                  errorImage: MemoryImage(_kTransparentTileBytes),
                  errorTileCallback: (_, _, _) {},
                ),
              // True metric 200m geofence circle + subtle 100m inner ring
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _officePoint,
                    radius: widget.allowedRadiusMeters,
                    useRadiusInMeter: true,
                    color: zoneColor.withValues(alpha: 0.16),
                    borderColor: zoneColor.withValues(alpha: 0.92),
                    borderStrokeWidth: 2.4,
                  ),
                  CircleMarker(
                    point: _officePoint,
                    radius: widget.allowedRadiusMeters * 0.5,
                    useRadiusInMeter: true,
                    color: Colors.transparent,
                    borderColor: zoneColor.withValues(alpha: 0.28),
                    borderStrokeWidth: 1.0,
                  ),
                ],
              ),
              // Distance connector line between office pin and nearby user pin
              if (showConnectorLine)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_officePoint, userPoint],
                      color: zoneColor.withValues(alpha: 0.88),
                      strokeWidth: 2.5,
                    ),
                  ],
                ),
              // Pinned office marker, 200m perimeter tag, and user location pin
              MarkerLayer(
                markers: [
                  Marker(
                    point: radiusTagPoint,
                    width: 46,
                    height: 20,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1E3D).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: zoneColor.withValues(alpha: 0.85),
                          ),
                        ),
                        child: Text(
                          '${widget.allowedRadiusMeters.round()}m',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Marker(
                    point: _officePoint,
                    width: 142,
                    height: 54,
                    alignment: Alignment.topCenter,
                    child: _OfficePinMarker(
                      label: _shortOfficeLabel(widget.officeName),
                    ),
                  ),
                  if (userPoint != null)
                    Marker(
                      point: userPoint,
                      width: 64,
                      height: 46,
                      alignment: Alignment.center,
                      child: _UserLocationMarker(
                        isInside: isInside ?? true,
                      ),
                    ),
                ],
              ),
            ],
          ),
          // Top-left live distance & geofence status pill
          Positioned(
            top: 8,
            left: 8,
            right: widget.isFullScreen ? 56 : 84,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B36).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: statusDot.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: statusDot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        statusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Top-right action buttons: Re-center + Expand to Full-Screen Real Map
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapIconButton(
                  key: const ValueKey('map_recenter_button'),
                  icon: Icons.my_location_rounded,
                  tooltip: 'Re-center on office',
                  onTap: () {
                    if (_simulation.mode == LocationSimulationMode.liveGps) {
                      _resolveLiveGps();
                    }
                    _refocusCamera(forceOfficeCenter: true);
                  },
                ),
                if (!widget.isFullScreen) ...[
                  const SizedBox(width: 6),
                  _MapIconButton(
                    key: const ValueKey('map_expand_button'),
                    icon: Icons.open_in_full_rounded,
                    tooltip: 'Open full-screen interactive map',
                    onTap: _openFullScreenMap,
                  ),
                ],
              ],
            ),
          ),
          // Bottom-left interactive tap-to-pin caption
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B36).withValues(alpha: 0.84),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 11,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.isFullScreen
                        ? 'Drag to pan • Tap map to move pin'
                        : 'Tap map to pin • Expand to pan',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom-right real map Zoom +/- controls
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    key: const ValueKey('map_zoom_in_button'),
                    onTap: () => _zoomBy(1.0),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                    child: const SizedBox(
                      width: 28,
                      height: 26,
                      child: Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    width: 20,
                    height: 1,
                    color: const Color(0xFFE2E8F0),
                  ),
                  InkWell(
                    key: const ValueKey('map_zoom_out_button'),
                    onTap: () => _zoomBy(-1.0),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(10),
                    ),
                    child: const SizedBox(
                      width: 28,
                      height: 26,
                      child: Icon(
                        Icons.remove_rounded,
                        size: 16,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.isFullScreen) {
      return SizedBox.expand(
        key: const ValueKey('office_geofence_map_fullscreen'),
        child: mapContent,
      );
    }

    return Container(
      key: const ValueKey('office_geofence_map'),
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EFF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: mapContent,
    );
  }
}

class _FullScreenOfficeMapPage extends StatelessWidget {
  const _FullScreenOfficeMapPage({
    required this.officeName,
    required this.officeLatitude,
    required this.officeLongitude,
    required this.allowedRadiusMeters,
    required this.locationService,
  });

  final String officeName;
  final double officeLatitude;
  final double officeLongitude;
  final double allowedRadiusMeters;
  final LocationService locationService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              officeName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            Text(
              '${allowedRadiusMeters.round()}m Permitted Attendance Geofence',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: OfficeGeofenceMap(
                officeName: officeName,
                officeLatitude: officeLatitude,
                officeLongitude: officeLongitude,
                allowedRadiusMeters: allowedRadiusMeters,
                locationService: locationService,
                isFullScreen: true,
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: StreamBuilder<LocationSimulationState>(
                stream: locationService.simulationStream,
                initialData: locationService.simulationState,
                builder: (context, snapshot) {
                  final mode = snapshot.data?.mode ??
                      LocationSimulationMode.liveGps;
                  return Row(
                    children: [
                      Expanded(
                        child: _QuickSimButton(
                          label: 'Inside (~25m)',
                          isSelected:
                              mode == LocationSimulationMode.insideOffice,
                          activeColor: const Color(0xFF059669),
                          onTap: () => locationService.updateSimulation(
                            const LocationSimulationState(
                              mode: LocationSimulationMode.insideOffice,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickSimButton(
                          label: 'Outside (~450m)',
                          isSelected:
                              mode == LocationSimulationMode.outsideOffice,
                          activeColor: const Color(0xFFD97706),
                          onTap: () => locationService.updateSimulation(
                            const LocationSimulationState(
                              mode: LocationSimulationMode.outsideOffice,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickSimButton(
                          label: 'Live GPS',
                          isSelected: mode == LocationSimulationMode.liveGps,
                          activeColor: const Color(0xFF1572B6),
                          onTap: () => locationService.updateSimulation(
                            const LocationSimulationState(
                              mode: LocationSimulationMode.liveGps,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSimButton extends StatelessWidget {
  const _QuickSimButton({
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? activeColor.withValues(alpha: 0.14)
          : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFE2E8F0),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isSelected ? activeColor : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.95),
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(
              icon,
              size: 16,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfficePinMarker extends StatelessWidget {
  const _OfficePinMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0B0D),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: const Color(0xFF10B981),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/teqbae_mark.png',
                width: 14,
                height: 14,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const CustomPaint(
          size: Size(10, 6),
          painter: _PinPointerPainter(color: Color(0xFF10B981)),
        ),
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker({required this.isInside});

  final bool isInside;

  @override
  Widget build(BuildContext context) {
    final color = isInside ? const Color(0xFF2563EB) : const Color(0xFFD97706);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
              ),
            ],
          ),
          child: const Text(
            'You',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PinPointerPainter extends CustomPainter {
  const _PinPointerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinPointerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _LightMapGridPainter extends CustomPainter {
  const _LightMapGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.45)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
