/// A single autocomplete suggestion returned by Nominatim.
class OsmPlaceSuggestion {
  /// Full display name from Nominatim (e.g. "Eiffel Tower, Paris, France").
  final String displayName;

  /// Short label — the first segment of [displayName] before the first comma.
  String get shortName => displayName.split(',').first.trim();

  /// Secondary label — everything after the first comma.
  String get subtitle {
    final idx = displayName.indexOf(',');
    return idx == -1 ? '' : displayName.substring(idx + 1).trim();
  }

  /// Latitude of this place.
  final double latitude;

  /// Longitude of this place.
  final double longitude;

  /// Nominatim OSM type (e.g. "node", "way", "relation").
  final String osmType;

  /// Human-readable place category (e.g. "city", "suburb", "tourism").
  final String category;

  const OsmPlaceSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.osmType,
    required this.category,
  });

  factory OsmPlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return OsmPlaceSuggestion(
      displayName: json['display_name'] as String? ?? '',
      latitude: double.tryParse(json['lat'] as String? ?? '0') ?? 0,
      longitude: double.tryParse(json['lon'] as String? ?? '0') ?? 0,
      osmType: json['osm_type'] as String? ?? '',
      category: json['type'] as String? ?? '',
    );
  }
}
