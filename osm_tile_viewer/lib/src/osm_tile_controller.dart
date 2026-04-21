import 'package:flutter/foundation.dart';
import 'models/osm_tile_result.dart';
import 'osm_tile_service.dart';

enum OsmTileStatus { idle, loading, success, error }

/// Controls map state: search, location-pin, and status.
class OsmTileController extends ChangeNotifier {
  OsmTileController({OsmTileService? service})
      : _service = service ?? const OsmTileService();

  final OsmTileService _service;

  OsmTileStatus _status = OsmTileStatus.idle;
  OsmTileResult? _result;
  String? _errorMessage;
  String _lastQuery = '';

  OsmTileStatus get status => _status;
  OsmTileResult? get result => _result;
  String? get errorMessage => _errorMessage;
  String get lastQuery => _lastQuery;
  bool get isLoading => _status == OsmTileStatus.loading;
  bool get hasResult => _status == OsmTileStatus.success && _result != null;
  bool get hasError => _status == OsmTileStatus.error;

  /// Geocodes [keyword] and loads the tile.
  Future<void> search(String keyword, {int zoom = 15}) async {
    _lastQuery = keyword;
    _status = OsmTileStatus.loading;
    _result = null;
    _errorMessage = null;
    notifyListeners();

    try {
      _result = await _service.search(keyword, zoom: zoom);
      _status = OsmTileStatus.success;
    } on OsmTileException catch (e) {
      _errorMessage = e.message;
      _status = OsmTileStatus.error;
    } catch (e) {
      _errorMessage = 'Unexpected error: $e';
      _status = OsmTileStatus.error;
    }

    notifyListeners();
  }

  /// Jump directly to known coordinates (from a suggestion tap) — no re-geocoding.
  Future<void> goToLocation({
    required double lat,
    required double lng,
    required String displayName,
    int zoom = 15,
  }) async {
    _lastQuery = displayName;
    _status = OsmTileStatus.loading;
    _result = null;
    _errorMessage = null;
    notifyListeners();

    try {
      _result = await _service.fetchTileForLocation(
        lat: lat,
        lng: lng,
        displayName: displayName,
        zoom: zoom,
      );
      _status = OsmTileStatus.success;
    } on OsmTileException catch (e) {
      _errorMessage = e.message;
      _status = OsmTileStatus.error;
    } catch (e) {
      _errorMessage = 'Unexpected error: $e';
      _status = OsmTileStatus.error;
    }

    notifyListeners();
  }

  void clear() {
    _status = OsmTileStatus.idle;
    _result = null;
    _errorMessage = null;
    _lastQuery = '';
    notifyListeners();
  }
}
