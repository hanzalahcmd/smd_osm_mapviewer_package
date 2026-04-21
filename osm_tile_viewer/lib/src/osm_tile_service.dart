import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'models/osm_tile_result.dart';
import 'models/osm_place_suggestion.dart';

/// Low-level service for Nominatim geocoding, autocomplete, and OSM tile fetching.
class OsmTileService {
  static const Map<String, String> _defaultHeaders = {
    'User-Agent':
        'OsmTileViewerPackage/0.1.0 (https://github.com/hanzalahcmd/smd_osm_mapviewer_package)',
    'Accept': 'image/png,image/*;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Referer': 'https://www.openstreetmap.org/',
    'Connection': 'keep-alive',
  };

  final Map<String, String>? customHeaders;
  const OsmTileService({this.customHeaders});
  Map<String, String> get _headers => customHeaders ?? _defaultHeaders;

  // ── Coordinate helpers ───────────────────────────────────────────────────

  int lonToTileX(double lon, int zoom) =>
      ((lon + 180) / 360 * pow(2, zoom)).floor();

  int latToTileY(double lat, int zoom) {
    final rad = lat * pi / 180;
    return ((1 - log(tan(rad) + 1 / cos(rad)) / pi) / 2 * pow(2, zoom))
        .floor();
  }

  // ── Autocomplete suggestions ─────────────────────────────────────────────

  /// Returns up to [limit] place suggestions for [query] via Nominatim.
  Future<List<OsmPlaceSuggestion>> suggest(String query, {int limit = 6}) async {
    if (query.trim().length < 2) return [];
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(query)}&format=json&limit=$limit&addressdetails=0',
    );
    try {
      final res = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as List<dynamic>;
      return data
          .map((e) => OsmPlaceSuggestion.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Full search + tile fetch ─────────────────────────────────────────────

  Future<OsmTileResult> search(String keyword, {int zoom = 15}) async {
    if (keyword.trim().isEmpty) throw const OsmTileException('Keyword is empty.');
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(keyword)}&format=json&limit=1',
    );
    http.Response geocodeRes;
    try {
      geocodeRes = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw OsmTileException('Network error during geocoding: $e');
    }
    if (geocodeRes.statusCode != 200) {
      throw OsmTileException('Nominatim HTTP ${geocodeRes.statusCode}');
    }
    List<dynamic> places;
    try {
      places = jsonDecode(geocodeRes.body) as List<dynamic>;
    } catch (e) {
      throw OsmTileException('Failed to parse Nominatim response: $e');
    }
    if (places.isEmpty) throw OsmTileException('Place not found: "$keyword"');
    final place = places.first as Map<String, dynamic>;
    final lat = double.parse(place['lat'] as String);
    final lng = double.parse(place['lon'] as String);
    final displayName = place['display_name'] as String? ?? keyword;
    return fetchTileForLocation(lat: lat, lng: lng, displayName: displayName, zoom: zoom);
  }

  /// Fetches the OSM tile for known coordinates — no re-geocoding needed.
  Future<OsmTileResult> fetchTileForLocation({
    required double lat,
    required double lng,
    required String displayName,
    int zoom = 15,
  }) async {
    final tileX = lonToTileX(lng, zoom);
    final tileY = latToTileY(lat, zoom);
    final tileUrl = 'https://tile.openstreetmap.org/$zoom/$tileX/$tileY.png';
    http.Response tileRes;
    try {
      tileRes = await http.get(Uri.parse(tileUrl), headers: _headers)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw OsmTileException('Network error fetching tile: $e');
    }
    if (tileRes.statusCode != 200) {
      throw OsmTileException('Tile HTTP ${tileRes.statusCode}');
    }
    return OsmTileResult(
      bytes: tileRes.bodyBytes,
      tileUrl: tileUrl,
      latitude: lat,
      longitude: lng,
      displayName: displayName,
      zoom: zoom,
      tileX: tileX,
      tileY: tileY,
    );
  }

  /// Fetches a single raw tile PNG — used by the interactive map internally.
  Future<Uint8List?> fetchRawTile(int zoom, int x, int y) async {
    final url = 'https://tile.openstreetmap.org/$zoom/$x/$y.png';
    try {
      final res = await http.get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200 ? res.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }
}

class OsmTileException implements Exception {
  final String message;
  const OsmTileException(this.message);
  @override
  String toString() => 'OsmTileException: $message';
}
