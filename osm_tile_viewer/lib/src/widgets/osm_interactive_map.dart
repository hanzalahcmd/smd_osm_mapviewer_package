import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../osm_tile_service.dart';

/// An interactive OpenStreetMap widget that supports pan and pinch-to-zoom.
///
/// Renders a full tile grid around [latitude]/[longitude] and places a red
/// pin at the searched location. Zoom buttons are provided for non-touch use.
class OsmInteractiveMap extends StatefulWidget {
  final double latitude;
  final double longitude;
  final int initialZoom;
  final double height;
  final OsmTileService service;

  const OsmInteractiveMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.service,
    this.initialZoom = 15,
    this.height = 420,
  });

  @override
  State<OsmInteractiveMap> createState() => _OsmInteractiveMapState();
}

class _OsmInteractiveMapState extends State<OsmInteractiveMap> {
  static const double _tileSize = 256.0;
  static const int _minZoom = 1;
  static const int _maxZoom = 19;

  late int _zoom;
  late double _cx; // world-pixel X of viewport center at _zoom
  late double _cy; // world-pixel Y of viewport center at _zoom

  // Visual scale factor within the current zoom level (0.5 – 2.0).
  // When it hits the boundary we snap to the next zoom level and reset.
  double _scale = 1.0;
  double _prevGestureScale = 1.0; // tracks previous d.scale for incremental calc

  // Pin location (updated when parent passes new lat/lng)
  late double _pinLat;
  late double _pinLng;

  // Tile cache: "zoom/x/y" → bytes (null = failed)
  final Map<String, Uint8List?> _cache = {};
  final Map<String, Future<Uint8List?>> _pending = {};

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _zoom = widget.initialZoom;
    _pinLat = widget.latitude;
    _pinLng = widget.longitude;
    _initCenter(widget.latitude, widget.longitude);
  }

  @override
  void didUpdateWidget(OsmInteractiveMap old) {
    super.didUpdateWidget(old);
    if (old.latitude != widget.latitude ||
        old.longitude != widget.longitude ||
        old.initialZoom != widget.initialZoom) {
      setState(() {
        _zoom = widget.initialZoom;
        _scale = 1.0;
        _pinLat = widget.latitude;
        _pinLng = widget.longitude;
        _initCenter(widget.latitude, widget.longitude);
      });
    }
  }

  // ── Coordinate math ──────────────────────────────────────────────────────

  void _initCenter(double lat, double lng) {
    _cx = _lonToWorld(lng, _zoom);
    _cy = _latToWorld(lat, _zoom);
  }

  double _lonToWorld(double lon, int zoom) =>
      (lon + 180) / 360 * pow(2, zoom) * _tileSize;

  double _latToWorld(double lat, int zoom) {
    final rad = lat * pi / 180;
    return (1 - log(tan(rad) + 1 / cos(rad)) / pi) / 2 * pow(2, zoom) * _tileSize;
  }

  // ── Gesture handlers ─────────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails d) {
    _prevGestureScale = 1.0;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      // ── Pan (works for both 1-finger drag and 2-finger pan) ──
      _cx -= d.focalPointDelta.dx / _scale;
      _cy -= d.focalPointDelta.dy / _scale;

      // ── Pinch zoom (only when 2+ pointers) ──
      if (d.pointerCount >= 2) {
        final increment = d.scale / _prevGestureScale;
        _prevGestureScale = d.scale;
        double ns = (_scale * increment).clamp(0.49, 2.01);

        if (ns >= 2.0 && _zoom < _maxZoom) {
          // Zoom in a level
          _zoom++;
          _cx *= 2;
          _cy *= 2;
          ns = 1.0;
          _prevGestureScale = d.scale;
        } else if (ns <= 0.5 && _zoom > _minZoom) {
          // Zoom out a level
          _zoom--;
          _cx /= 2;
          _cy /= 2;
          ns = 1.0;
          _prevGestureScale = d.scale;
        }

        _scale = ns.clamp(0.5, 2.0);
      }
    });
  }

  void _changeZoom(int delta) {
    setState(() {
      final nz = (_zoom + delta).clamp(_minZoom, _maxZoom);
      if (nz == _zoom) return;
      if (delta > 0) {
        _cx *= 2;
        _cy *= 2;
      } else {
        _cx /= 2;
        _cy /= 2;
      }
      _zoom = nz;
      _scale = 1.0;
    });
  }

  // ── Tile fetching ────────────────────────────────────────────────────────

  Future<Uint8List?> _getTile(int zoom, int x, int y) {
    final key = '$zoom/$x/$y';
    if (_cache.containsKey(key)) return Future.value(_cache[key]);
    return _pending.putIfAbsent(key, () async {
      final bytes = await widget.service.fetchRawTile(zoom, x, y);
      _cache[key] = bytes;
      _pending.remove(key);
      return bytes;
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              child: Stack(
                children: [
                  // Grey background before tiles load
                  Container(color: const Color(0xFFE0E4EA)),
                  // Tile grid
                  ..._buildTiles(w, h),
                  // Location pin
                  _buildPin(w, h),
                  // Zoom controls
                  _buildZoomControls(),
                  // OSM attribution (required by OSM tile usage policy)
                  _buildAttribution(),
                  // Zoom level badge
                  _buildZoomBadge(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Tile grid ────────────────────────────────────────────────────────────

  List<Widget> _buildTiles(double w, double h) {
    final ets = _tileSize * _scale; // effective tile size in screen pixels
    final leftWorld = _cx - w / 2 / _scale;
    final topWorld = _cy - h / 2 / _scale;

    final startX = (leftWorld / _tileSize).floor();
    final startY = (topWorld / _tileSize).floor();
    final endX = ((leftWorld + w / _scale) / _tileSize).ceil();
    final endY = ((topWorld + h / _scale) / _tileSize).ceil();

    final maxTile = pow(2, _zoom).toInt();
    final tiles = <Widget>[];

    for (int tx = startX; tx < endX; tx++) {
      for (int ty = startY; ty < endY; ty++) {
        // Clamp Y, wrap X (OSM tiles wrap around longitude)
        if (ty < 0 || ty >= maxTile) continue;
        final wrappedX = ((tx % maxTile) + maxTile) % maxTile;

        final screenLeft = (tx * _tileSize - leftWorld) * _scale;
        final screenTop = (ty * _tileSize - topWorld) * _scale;

        tiles.add(Positioned(
          left: screenLeft,
          top: screenTop,
          width: ets,
          height: ets,
          child: _TileImage(
            zoom: _zoom,
            x: wrappedX,
            y: ty,
            fetcher: _getTile,
          ),
        ));
      }
    }
    return tiles;
  }

  // ── Pin ──────────────────────────────────────────────────────────────────

  Widget _buildPin(double w, double h) {
    final worldX = _lonToWorld(_pinLng, _zoom);
    final worldY = _latToWorld(_pinLat, _zoom);
    final screenX = (worldX - _cx) * _scale + w / 2;
    final screenY = (worldY - _cy) * _scale + h / 2;

    const pinH = 40.0;
    const pinW = 32.0;

    if (screenX < -pinW || screenX > w + pinW ||
        screenY < -pinH || screenY > h + 16) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: screenX - pinW / 2,
      top: screenY - pinH, // pin tip points to exact location
      child: const Icon(
        Icons.location_pin,
        color: Colors.red,
        size: pinH,
        shadows: [Shadow(blurRadius: 6, color: Colors.black45)],
      ),
    );
  }

  // ── UI overlays ──────────────────────────────────────────────────────────

  Widget _buildZoomControls() {
    return Positioned(
      right: 12,
      bottom: 48,
      child: Column(
        children: [
          _ZoomBtn(icon: Icons.add, onTap: () => _changeZoom(1)),
          const SizedBox(height: 6),
          _ZoomBtn(icon: Icons.remove, onTap: () => _changeZoom(-1)),
        ],
      ),
    );
  }

  Widget _buildAttribution() {
    return Positioned(
      left: 4,
      bottom: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Text(
          '© OpenStreetMap contributors',
          style: TextStyle(fontSize: 9, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildZoomBadge() {
    return Positioned(
      right: 12,
      top: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'z$_zoom',
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }
}

// ── Tile image widget ────────────────────────────────────────────────────────

class _TileImage extends StatelessWidget {
  final int zoom, x, y;
  final Future<Uint8List?> Function(int zoom, int x, int y) fetcher;

  const _TileImage({
    required this.zoom,
    required this.x,
    required this.y,
    required this.fetcher,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: fetcher(zoom, x, y),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.done &&
            snap.data != null) {
          return Image.memory(
            snap.data!,
            fit: BoxFit.fill,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          );
        }
        // Show placeholder while loading (or on error)
        return Container(color: const Color(0xFFDDE3EC));
      },
    );
  }
}

// ── Zoom button ──────────────────────────────────────────────────────────────

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ZoomBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(blurRadius: 6, color: Colors.black26, offset: Offset(0, 2))
          ],
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }
}
