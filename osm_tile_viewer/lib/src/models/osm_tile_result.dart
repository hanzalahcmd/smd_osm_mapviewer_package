import 'dart:typed_data';

/// Holds the result of a successful OSM tile fetch.
class OsmTileResult {
  /// The raw PNG bytes of the tile image.
  final Uint8List bytes;

  /// The full URL of the tile that was fetched.
  final String tileUrl;

  /// The latitude of the resolved location.
  final double latitude;

  /// The longitude of the resolved location.
  final double longitude;

  /// The display name returned by Nominatim for the searched place.
  final String displayName;

  /// The zoom level used when fetching this tile.
  final int zoom;

  /// The tile X coordinate.
  final int tileX;

  /// The tile Y coordinate.
  final int tileY;

  const OsmTileResult({
    required this.bytes,
    required this.tileUrl,
    required this.latitude,
    required this.longitude,
    required this.displayName,
    required this.zoom,
    required this.tileX,
    required this.tileY,
  });
}
