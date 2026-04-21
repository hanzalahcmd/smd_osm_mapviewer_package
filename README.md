# osm_tile_viewer

A Flutter package for searching places and displaying interactive [OpenStreetMap](https://www.openstreetmap.org/) tiles — no API key required.

Type any city, landmark, or address into the search bar and get live autocomplete suggestions powered by **Nominatim**. Select a result to open a fully interactive map you can pan and pinch-to-zoom.

---

## Screenshots

### Idle state — app on launch before any search

![Idle state](https://github.com/hanzalahcmd/smd_osm_mapviewer_package/blob/main/osm_tile_viewer/%7BEF6372CF-6231-4589-B300-ACE0E44CCB62%7D.png)

---

### Suggestive search — dropdown appears as you type

![Suggestive search](https://github.com/hanzalahcmd/smd_osm_mapviewer_package/blob/main/osm_tile_viewer/%7B9B82D9B0-B134-42FA-BF5E-2ED357C89CB1%7D.png)

---

### Suggestion selected — map loads with location pin

![Suggestion selected](https://github.com/hanzalahcmd/smd_osm_mapviewer_package/blob/main/osm_tile_viewer/%7B313B38CE-913B-4B98-B66E-122BBDC846B4%7D.png)

---

### Panning the map — dragging to explore the area

![Panning the map](https://github.com/hanzalahcmd/smd_osm_mapviewer_package/blob/main/osm_tile_viewer/%7B310352E0-4A3F-4F7A-AF08-29BB063A2F9F%7D.png)

---

### Zooming out to see more context

![Zoom out](https://github.com/hanzalahcmd/smd_osm_mapviewer_package/blob/main/osm_tile_viewer/%7BC04DF206-103E-4408-B10E-F4E1F7DB3443%7D.png)

---

### Zoom in

![Zoom in](https://github.com/hanzalahcmd/smd_osm_mapviewer_package/blob/main/osm_tile_viewer/%7B313B38CE-913B-4B98-B66E-122BBDC846B4%7D.png)

---


### Error state — place not found

![Error state](https://github.com/hanzalahcmd/smd_osm_mapviewer_package/blob/main/osm_tile_viewer/%7BC62B9BD2-E8CD-4BED-A400-321A734C99D3%7D.png)

---

## Features

- 🔍 **Live suggestions** as you type — debounced at 350 ms, shows up to 6 results
- 🗂 **Smart category icons** per suggestion (city, airport, restaurant, museum, etc.)
- 🗺 **Interactive tile map** — full OSM tile grid, not just a single image
- 👆 **Pan** with one finger or click-drag
- 🤏 **Pinch-to-zoom** — snaps to OSM zoom levels automatically
- ➕➖ **Zoom buttons** for keyboard/mouse users
- 📍 **Location pin** at the exact searched coordinates
- ⚡ **Tile cache** — tiles already downloaded are never re-fetched on pan
- 🔑 **No API key** — uses Nominatim and the public OSM tile server
- 🎨 **Fully customisable** — zoom, map height, debounce timing, callbacks

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  osm_tile_viewer: ^0.1.0
```

Then run:

```bash
flutter pub get
```

---

## Quick start

### Drop-in widget (zero config)

```dart
import 'package:osm_tile_viewer/osm_tile_viewer.dart';

// Anywhere in your widget tree:
const OsmTileViewer()
```

### With a controller and callbacks

```dart
import 'package:osm_tile_viewer/osm_tile_viewer.dart';

class MyPage extends StatefulWidget { ... }

class _MyPageState extends State<MyPage> {
  final _controller = OsmTileController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OsmTileViewer(
      controller: _controller,
      zoom: 15,
      mapHeight: 440,
      searchHint: 'Search cities, landmarks, addresses…',
      searchDebounce: const Duration(milliseconds: 350),
      onTileLoaded: (result) {
        print('Loaded: ${result.displayName}');
        print('Lat: ${result.latitude}, Lng: ${result.longitude}');
      },
      onError: (message) {
        print('Error: $message');
      },
    );
  }
}
```

### Trigger a search programmatically

```dart
// Search by keyword (geocodes via Nominatim first)
_controller.search('Sydney Opera House', zoom: 14);

// Jump straight to known coordinates (no geocoding round-trip)
_controller.goToLocation(
  lat: 51.5074,
  lng: -0.1278,
  displayName: 'London, England',
  zoom: 13,
);
```

### Headless — raw data, no widget

```dart
final service = OsmTileService();

// Get suggestions as the user types
final suggestions = await service.suggest('tokyo sta');
// → List<OsmPlaceSuggestion> with lat, lng, displayName, category

// Full search + tile fetch
final result = await service.search('Colosseum Rome', zoom: 16);
// result.bytes       → Uint8List PNG of the tile
// result.latitude    → double
// result.longitude   → double
// result.displayName → "Colosseum, Via Sacra, ..."
// result.tileUrl     → full OSM tile URL
```

---

## OsmTileViewer parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `controller` | `OsmTileController?` | auto-created | External controller for programmatic use |
| `zoom` | `int` | `15` | Initial OSM zoom level (1–19) |
| `mapHeight` | `double` | `420` | Height of the interactive map in logical pixels |
| `searchHint` | `String` | `'Search for a place…'` | Placeholder text in the search field |
| `searchDebounce` | `Duration` | `350 ms` | Delay before hitting Nominatim as user types |
| `onTileLoaded` | `void Function(OsmTileResult)?` | — | Fires when a location loads successfully |
| `onError` | `void Function(String)?` | — | Fires when geocoding or tile fetch fails |
| `padding` | `EdgeInsetsGeometry` | `EdgeInsets.all(16)` | Outer padding around the widget content |

---

## OsmTileResult properties

| Property | Type | Description |
|---|---|---|
| `bytes` | `Uint8List` | Raw PNG bytes of the centre tile |
| `tileUrl` | `String` | Full URL of the fetched tile |
| `latitude` | `double` | Latitude of the resolved location |
| `longitude` | `double` | Longitude of the resolved location |
| `displayName` | `String` | Full Nominatim place name |
| `zoom` | `int` | Zoom level used |
| `tileX` / `tileY` | `int` | OSM tile grid coordinates |

---

## OsmPlaceSuggestion properties

| Property | Type | Description |
|---|---|---|
| `displayName` | `String` | Full name from Nominatim |
| `shortName` | `String` | First segment before the first comma |
| `subtitle` | `String` | Everything after the first comma |
| `latitude` | `double` | Latitude |
| `longitude` | `double` | Longitude |
| `category` | `String` | OSM place type (e.g. `"city"`, `"tourism"`) |
| `osmType` | `String` | OSM element type (`"node"`, `"way"`, `"relation"`) |

---

## Running the example app

```bash
cd example
flutter pub get

# Chrome (fastest, no setup)
flutter run -d chrome

# Android phone (enable USB debugging first)
flutter devices
flutter run
```

---

## Architecture

```
lib/
├── osm_tile_viewer.dart          ← public exports
└── src/
    ├── models/
    │   ├── osm_tile_result.dart        ← result of a full search
    │   └── osm_place_suggestion.dart   ← single autocomplete item
    ├── widgets/
    │   ├── osm_search_bar.dart         ← debounced field + suggestions dropdown
    │   └── osm_interactive_map.dart    ← pan/zoom tile grid + pin
    ├── osm_tile_service.dart           ← Nominatim + OSM tile HTTP calls
    ├── osm_tile_controller.dart        ← ChangeNotifier state management
    └── osm_tile_viewer_widget.dart     ← assembles everything
```

---

## OSM usage policy

This package follows the [OpenStreetMap Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/). Every request sets a descriptive `User-Agent` and `Referer` header. The built-in tile cache avoids re-fetching the same tile on pan. Please respect the Nominatim usage policy (max 1 request/second) — the default 350 ms debounce keeps you well within limits.

---

## License

MIT © hanzalahcmd
