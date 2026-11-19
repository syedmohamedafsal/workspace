import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import 'geo_distance_calculator.dart';
import 'location_models.dart';
import 'location_service.dart';

/// 1x1 transparent PNG fallback tile when offline
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

/// Completely free, zero-plugin TileProvider that loads real map tiles
/// via Flutter's built-in [NetworkImage], bypassing native path_provider channels.
class DirectNetworkTileProvider extends TileProvider {
  DirectNetworkTileProvider({super.headers});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return NetworkImage(
      url,
      headers: {
        'User-Agent': 'rebs_hrms_app/1.0 (Flutter; Mobile Office)',
        ...headers,
      },
    );
  }
}

/// Available free real map tile layers (OpenStreetMap, Carto Voyager, and Satellite).
enum MapLayerType {
  osm('Street (OSM)', 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
  carto('Modern', 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png'),
  satellite(
    'Satellite',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  );

  const MapLayerType(this.label, this.urlTemplate);
  final String label;
  final String urlTemplate;
}

/// Real interactive street map view with:
/// - 3D Isometric Office Building marker at Teqbae Kochi HQ
/// - 3D Standing Person Character avatar representing the user
/// - True metric 200m radius geofence ring
/// - Free real map tile layers (Street OSM / Satellite / Modern)
/// - Zoom, re-center, tap-to-pin, and full-screen map expansion
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
  final DirectNetworkTileProvider _tileProvider = DirectNetworkTileProvider();
  StreamSubscription<LocationSimulationState>? _simSub;

  late LocationSimulationState _simulation;
  LatLng? _liveUserPoint;
  bool _isResolvingLiveGps = false;
  String? _liveGpsNote;
  bool _mapReady = false;
  MapLayerType _selectedLayer = MapLayerType.osm;

  LatLng get _officePoint =>
      LatLng(widget.officeLatitude, widget.officeLongitude);

  double get _defaultZoom => widget.isFullScreen ? 16.5 : 15.8;

  bool get _isRunningInWidgetTest {
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    return bindingName.contains('Test');
  }

  bool get _shouldLoadNetworkTiles =>
      widget.enableNetworkTiles ?? !_isRunningInWidgetTest;

  @override
  void initState() {
    super.initState();
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
            : const EdgeInsets.fromLTRB(36, 48, 36, 36),
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

  void _cycleLayer() {
    setState(() {
      _selectedLayer = switch (_selectedLayer) {
        MapLayerType.osm => MapLayerType.satellite,
        MapLayerType.satellite => MapLayerType.carto,
        MapLayerType.carto => MapLayerType.osm,
      };
    });
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
          // Underlying cartographic grid background
          const ColoredBox(
            color: Color(0xFFE2E8F0),
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
                  key: ValueKey('map_layer_${_selectedLayer.name}'),
                  urlTemplate: _selectedLayer.urlTemplate,
                  userAgentPackageName: 'com.rebs.rebs',
                  tileProvider: _tileProvider,
                  errorImage: MemoryImage(_kTransparentTileBytes),
                  errorTileCallback: (_, _, _) {},
                ),
              // True metric 200m geofence circle + subtle 100m inner guide
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
              // Distance connector line between office and user
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
              // 3D Office Building, 3D Standing Person, and 200m perimeter badge
              MarkerLayer(
                markers: [
                  // 200m perimeter tag on eastern radius
                  Marker(
                    point: radiusTagPoint,
                    width: 46,
                    height: 20,
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1E3D).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: zoneColor.withValues(alpha: 0.85),
                        ),
                      ),
                      alignment: Alignment.center,
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
                  // 3D Isometric Office Building (anchored bottom-center at office coordinates)
                  Marker(
                    point: _officePoint,
                    width: 140,
                    height: 112,
                    alignment: Alignment.bottomCenter,
                    child: _Isometric3DBuildingMarker(
                      label: _shortOfficeLabel(widget.officeName),
                    ),
                  ),
                  // 3D Standing Person Character avatar (anchored bottom-center at user coordinates)
                  if (userPoint != null)
                    Marker(
                      point: userPoint,
                      width: 90,
                      height: 88,
                      alignment: Alignment.bottomCenter,
                      child: _Isometric3DPersonMarker(
                        isInside: isInside ?? true,
                      ),
                    ),
                ],
              ),
            ],
          ),
          // Top-left live status pill
          Positioned(
            top: 8,
            left: 8,
            right: widget.isFullScreen ? 56 : 118,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B36).withValues(alpha: 0.92),
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
          // Top-right action buttons: Layer Switcher + Re-center + Full-screen
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapIconButton(
                  key: const ValueKey('map_layer_toggle_button'),
                  icon: Icons.layers_rounded,
                  tooltip: 'Layer: ${_selectedLayer.label}',
                  onTap: _cycleLayer,
                ),
                const SizedBox(width: 6),
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
          // Bottom-left interactive hint
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B36).withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 11,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.isFullScreen
                        ? 'Drag to pan • Tap to place 3D person'
                        : 'Tap map to place 3D person',
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
          // Bottom-right Zoom +/- controls
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
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
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

/// 3D Isometric Office Building marker placed at the office location.
/// Displays a multi-story corporate glass-and-steel tower with illuminated
/// windows, helipad, and Teqbae mark.
class _Isometric3DBuildingMarker extends StatelessWidget {
  const _Isometric3DBuildingMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Floating glassmorphic office label pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0B0D).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: const Color(0xFF10B981),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/teqbae_mark.png',
                width: 13,
                height: 13,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 4),
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
        const SizedBox(height: 2),
        // 3D Isometric Tower Model
        const CustomPaint(
          size: Size(68, 76),
          painter: _IsometricBuildingPainter(),
        ),
      ],
    );
  }
}

/// CustomPainter rendering a 3D isometric modern office tower with lit windows,
/// roof terrace, and ground anchor shadow.
class _IsometricBuildingPainter extends CustomPainter {
  const _IsometricBuildingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const w = 68.0;
    const h = 76.0;

    // 1. Soft ground contact shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(w / 2 + 6, h - 8), width: 52, height: 16),
      shadowPaint,
    );

    // 2. Emerald GPS ground anchor glow
    final anchorGlowPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(w / 2, h - 9), width: 38, height: 13),
      anchorGlowPaint,
    );

    // Geometry coordinates
    const pCenterBase = Offset(w / 2, h - 9);
    const pLeftBase = Offset(12, h - 21);
    const pRightBase = Offset(w - 12, h - 21);
    const pCenterTop = Offset(w / 2, 28);
    const pLeftTop = Offset(12, 16);
    const pRightTop = Offset(w - 12, 16);
    const pRoofApex = Offset(w / 2, 5);

    // 3. Left Wall (Ambient / Slate Blue)
    final leftWallPath = Path()
      ..moveTo(pLeftTop.dx, pLeftTop.dy)
      ..lineTo(pCenterTop.dx, pCenterTop.dy)
      ..lineTo(pCenterBase.dx, pCenterBase.dy)
      ..lineTo(pLeftBase.dx, pLeftBase.dy)
      ..close();

    final leftWallPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
      ).createShader(Rect.fromLTRB(12, 16, w / 2, h - 9));
    canvas.drawPath(leftWallPath, leftWallPaint);

    // 4. Right Wall (Sunlit / Corporate Steel)
    final rightWallPath = Path()
      ..moveTo(pCenterTop.dx, pCenterTop.dy)
      ..lineTo(pRightTop.dx, pRightTop.dy)
      ..lineTo(pRightBase.dx, pRightBase.dy)
      ..lineTo(pCenterBase.dx, pCenterBase.dy)
      ..close();

    final rightWallPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFF334155), Color(0xFF1E293B)],
      ).createShader(Rect.fromLTRB(w / 2, 16, w - 12, h - 9));
    canvas.drawPath(rightWallPath, rightWallPaint);

    // 5. Floor dividers & illuminated window grid
    final windowLitPaint = Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.85);
    final windowDimPaint = Paint()..color = const Color(0xFF67E8F9).withValues(alpha: 0.45);
    final floorLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 4; i++) {
      final t = i / 5.0;
      final yL = pLeftTop.dy + (pLeftBase.dy - pLeftTop.dy) * t;
      final yC = pCenterTop.dy + (pCenterBase.dy - pCenterTop.dy) * t;
      final yR = pRightTop.dy + (pRightBase.dy - pRightTop.dy) * t;

      // Floor divider strokes
      canvas.drawLine(Offset(pLeftTop.dx, yL), Offset(pCenterTop.dx, yC), floorLinePaint);
      canvas.drawLine(Offset(pCenterTop.dx, yC), Offset(pRightTop.dx, yR), floorLinePaint);

      // Windows on Left Wall
      for (int wIdx = 0; wIdx < 3; wIdx++) {
        final wt = (wIdx + 1) / 4.0;
        final wx = pLeftTop.dx + (pCenterTop.dx - pLeftTop.dx) * wt;
        final wy = yL + (yC - yL) * wt - 4;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(wx - 2, wy, 4, 3), const Radius.circular(1)),
          (i + wIdx) % 2 == 0 ? windowLitPaint : windowDimPaint,
        );
      }

      // Windows on Right Wall
      for (int wIdx = 0; wIdx < 3; wIdx++) {
        final wt = (wIdx + 1) / 4.0;
        final wx = pCenterTop.dx + (pRightTop.dx - pCenterTop.dx) * wt;
        final wy = yC + (yR - yC) * wt - 4;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(wx - 2, wy, 4, 3), const Radius.circular(1)),
          (i * wIdx) % 2 == 0 ? windowLitPaint : windowDimPaint,
        );
      }
    }

    // 6. Ground Entrance Canopy with warm golden light
    final entrancePath = Path()
      ..moveTo(w / 2 - 6, h - 16)
      ..lineTo(w / 2 + 6, h - 16)
      ..lineTo(w / 2 + 6, h - 10)
      ..lineTo(w / 2 - 6, h - 10)
      ..close();
    final entrancePaint = Paint()..color = const Color(0xFFFDE68A);
    canvas.drawPath(entrancePath, entrancePaint);

    // 7. Roof Deck (Isometric Rhombus)
    final roofPath = Path()
      ..moveTo(pRoofApex.dx, pRoofApex.dy)
      ..lineTo(pRightTop.dx, pRightTop.dy)
      ..lineTo(pCenterTop.dx, pCenterTop.dy)
      ..lineTo(pLeftTop.dx, pLeftTop.dy)
      ..close();

    final roofPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0F1E3D), Color(0xFF1E3A8A)],
      ).createShader(Rect.fromLTRB(12, 5, w - 12, 28));
    canvas.drawPath(roofPath, roofPaint);

    // Roof border highlight
    final roofBorderPaint = Paint()
      ..color = const Color(0xFF60A5FA).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(roofPath, roofBorderPaint);

    // 8. Rooftop Helipad ring
    final helipadPaint = Paint()
      ..color = const Color(0xFFFCD34D).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(w / 2, 17), width: 14, height: 7),
      helipadPaint,
    );

    // 9. Steel Antenna Mast with pulsing red beacon
    final mastPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(w / 2, 5), const Offset(w / 2, -2), mastPaint);

    final beaconPaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawCircle(const Offset(w / 2, -2), 2.2, beaconPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 3D Standing Person Character marker placed at the user's location.
/// Renders a modern isometric standing developer character with 3D volumetric
/// lighting, shoes, trousers, jacket, lanyard, and anchor shadow.
class _Isometric3DPersonMarker extends StatelessWidget {
  const _Isometric3DPersonMarker({required this.isInside});

  final bool isInside;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        isInside ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Floating Name Tag with dynamic distance beacon
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B36).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.7),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'You',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 1),
        // 3D Person Character CustomPaint
        CustomPaint(
          size: const Size(42, 60),
          painter: _Person3DPainter(isInside: isInside),
        ),
      ],
    );
  }
}

/// CustomPainter that renders a stylized 3D isometric character model standing:
/// - 3D head with volume, skin tone highlights, and dark styled hair
/// - Fitted azure developer hoodie/blazer with lanyard
/// - Tailored dark slacks with lighting crease
/// - 3D sneakers planted on an interactive anchor aura
class _Person3DPainter extends CustomPainter {
  const _Person3DPainter({required this.isInside});

  final bool isInside;

  @override
  void paint(Canvas canvas, Size size) {
    const cx = 21.0;

    // 1. Ground contact shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(cx, 56), width: 26, height: 9),
      shadowPaint,
    );

    // 2. Active Geofence ground anchor ring
    final ringColor =
        isInside ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final anchorRingPaint = Paint()
      ..color = ringColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(cx, 56), width: 32, height: 11),
      anchorRingPaint,
    );

    // 3. 3D Shoes (white sole + dark navy leather top)
    final solePaint = Paint()..color = const Color(0xFFF1F5F9);
    final shoeTopPaint = Paint()..color = const Color(0xFF0F172A);

    // Left shoe
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(13, 53, 6.5, 3), const Radius.circular(1.5)),
      shoeTopPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(13, 55, 6.5, 1.5), const Radius.circular(0.8)),
      solePaint,
    );

    // Right shoe
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(22.5, 53, 6.5, 3), const Radius.circular(1.5)),
      shoeTopPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(22.5, 55, 6.5, 1.5), const Radius.circular(0.8)),
      solePaint,
    );

    // 4. Tailored Trousers / Legs (3D cylinder lighting)
    final pantsPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF334155), Color(0xFF0F172A)],
      ).createShader(const Rect.fromLTWH(12, 38, 18, 16));

    // Left leg
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(13.5, 38, 6.5, 16), const Radius.circular(2)),
      pantsPaint,
    );
    // Right leg
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(22, 38, 6.5, 16), const Radius.circular(2)),
      pantsPaint,
    );

    // 5. Torso / 3D Corporate Developer Jacket
    final jacketPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
      ).createShader(const Rect.fromLTWH(12, 20, 18, 19));

    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(12.5, 20, 17, 19), const Radius.circular(4)),
      jacketPaint,
    );

    // Inner shirt collar
    final collarPaint = Paint()..color = Colors.white;
    final collarPath = Path()
      ..moveTo(18, 20)
      ..lineTo(cx, 24)
      ..lineTo(24, 20)
      ..close();
    canvas.drawPath(collarPath, collarPaint);

    // Developer Lanyard & Mini Badge
    final lanyardPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 1.0;
    canvas.drawLine(const Offset(19, 20), const Offset(cx, 28), lanyardPaint);
    canvas.drawLine(const Offset(23, 20), const Offset(cx, 28), lanyardPaint);

    final badgeCardPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(cx, 30.5), width: 4.5, height: 4), const Radius.circular(0.8)),
      badgeCardPaint,
    );

    // 6. Arms & Hands (holding a phone on the right hand)
    final armPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0284C7), Color(0xFF075985)],
      ).createShader(const Rect.fromLTWH(9, 21, 24, 16));

    // Left arm
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(9, 21, 4.5, 15), const Radius.circular(2.5)),
      armPaint,
    );

    // Right arm (angled)
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(28.5, 21, 4.5, 13), const Radius.circular(2.5)),
      armPaint,
    );

    // Hands
    final skinPaint = Paint()..color = const Color(0xFFE0AC8A);
    canvas.drawCircle(const Offset(11, 37), 2.2, skinPaint); // left hand
    canvas.drawCircle(const Offset(31, 34), 2.2, skinPaint); // right hand

    // Mini smartphone in right hand
    final phonePaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(30, 31, 3.2, 5.5), const Radius.circular(0.8)),
      phonePaint,
    );
    final phoneScreenPaint = Paint()..color = const Color(0xFF38BDF8);
    canvas.drawRect(const Rect.fromLTWH(30.4, 31.5, 2.4, 4.5), phoneScreenPaint);

    // 7. Neck & 3D Volumetric Head
    canvas.drawRect(const Rect.fromLTWH(cx - 2, 16, 4, 4.5), skinPaint);

    final headPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.3),
        radius: 0.8,
        colors: [Color(0xFFF5D0B5), Color(0xFFC68642)],
      ).createShader(const Rect.fromLTWH(15.5, 6, 11, 12));

    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(15.5, 6, 11, 12), const Radius.circular(5.5)),
      headPaint,
    );

    // 8. 3D Dark Styled Hair
    final hairPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1E293B), Color(0xFF090D16)],
      ).createShader(const Rect.fromLTWH(15, 4, 12, 7));

    final hairPath = Path()
      ..moveTo(15, 11)
      ..cubicTo(15, 3.5, 27, 3.5, 27, 11)
      ..lineTo(27, 8)
      ..cubicTo(25, 4.5, 17, 4.5, 15, 8)
      ..close();
    canvas.drawPath(hairPath, hairPaint);
  }

  @override
  bool shouldRepaint(covariant _Person3DPainter oldDelegate) =>
      oldDelegate.isInside != isInside;
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
