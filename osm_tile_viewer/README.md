# osm_tile_viewer

A Flutter package that lets you search for any place by name and display its [OpenStreetMap](https://www.openstreetmap.org/) tile — no API key required.

It uses **Nominatim** for geocoding and fetches tiles directly from the OSM tile server with the correct headers to avoid 403 errors.

---

## Features

- 🔍 Search any place by keyword (powered by Nominatim)
- 🗺 Renders the OSM tile for that location
- 🎛 Optional `OsmTileController` for programmatic control
- 🛠 `OsmTileService` available for headless / raw-data usage
- 🎨 Fully customisable: zoom, tile size, loading widget, error widget, callbacks

---

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  osm_tile_viewer: ^0.1.0
```

Then run:

```
flutter pub get
```

---

## Usage

### Drop-in widget (zero config)

```dart
import 'package:osm_tile_viewer/osm_tile_viewer.dart';

// Inside your widget tree:
const OsmTileViewer()
```

### With a controller (programmatic search + callbacks)

```dart
final _controller = OsmTileController();

@override
void dispose() {
  _controller.dispose();
  super.dispose();
}

// Trigger a search from anywhere in your code:
_controller.search('Eiffel Tower', zoom: 14);

// In your build method:
OsmTileViewer(
  controller: _controller,
  zoom: 14,
  tileSize: 300,
  showTileUrl: false,
  onTileLoaded: (result) {
    print('Loaded: ${result.displayName}');
    print('Lat: ${result.latitude}, Lng: ${result.longitude}');
  },
  onError: (msg) => print('Error: $msg'),
)
```

### Headless — raw data, no widget

```dart
final service = OsmTileService();
final result = await service.search('Sydney Opera House', zoom: 15);

// result.bytes      → Uint8List PNG bytes
// result.tileUrl    → full tile URL string
// result.latitude   → double
// result.longitude  → double
// result.displayName → full Nominatim place name
```

---

## OsmTileViewer parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `controller` | `OsmTileController?` | auto-created | External controller for programmatic use |
| `zoom` | `int` | `15` | OSM zoom level (1–19) |
| `tileSize` | `double` | `256` | Width and height of the tile in logical pixels |
| `searchHint` | `String` | `'Enter a place…'` | Search field placeholder |
| `showTileUrl` | `bool` | `true` | Show the tile URL below the image |
| `onTileLoaded` | `void Function(OsmTileResult)?` | — | Callback when tile loads successfully |
| `onError` | `void Function(String)?` | — | Callback when an error occurs |
| `loadingWidget` | `Widget?` | `CircularProgressIndicator` | Custom loading indicator |
| `errorBuilder` | `Widget Function(String)?` | built-in | Custom error widget builder |
| `placeholderWidget` | `Widget?` | built-in text | Widget shown before first search |
| `padding` | `EdgeInsetsGeometry` | `EdgeInsets.all(16)` | Padding around the content |

---

## OSM Usage Policy

This package follows the [OpenStreetMap Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/). It sets an appropriate `User-Agent` and `Referer` header on every request. Please respect the OSM tile server's rate limits in your apps.

---

## License

MIT
