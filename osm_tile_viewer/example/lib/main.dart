import 'package:flutter/material.dart';
import 'package:osm_tile_viewer/osm_tile_viewer.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OSM Tile Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A7DFF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const MapPage(),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _controller = OsmTileController();
  String _statusText = 'Ready';
  int _zoom = 15;

  static const _quickSearches = [
    ('🗼', 'Eiffel Tower'),
    ('🗽', 'New York'),
    ('🌊', 'Sydney'),
    ('🏯', 'Tokyo'),
    ('🕌', 'Dubai'),
    ('🏔', 'Karachi'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      appBar: AppBar(
        title: const Text('OSM Interactive Map'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Zoom selector
          PopupMenuButton<int>(
            icon: const Icon(Icons.layers_outlined),
            tooltip: 'Zoom level',
            initialValue: _zoom,
            onSelected: (z) => setState(() => _zoom = z),
            itemBuilder: (_) => [
              for (final z in [10, 12, 14, 15, 16, 17])
                PopupMenuItem(
                  value: z,
                  child: Text('Zoom $z${z == _zoom ? ' ✓' : ''}'),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick-search chips
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _quickSearches.map((entry) {
                    final (emoji, place) = entry;
                    return ActionChip(
                      avatar: Text(emoji),
                      label: Text(place),
                      onPressed: () {
                        setState(() => _statusText = 'Searching…');
                        _controller.search(place, zoom: _zoom);
                      },
                    );
                  }).toList(),
                ),
              ),

              // Status bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey(_statusText),
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .secondaryContainer
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusText,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),

              // Main widget
              OsmTileViewer(
                controller: _controller,
                zoom: _zoom,
                mapHeight: 440,
                searchHint: 'Search cities, landmarks, addresses…',
                searchDebounce: const Duration(milliseconds: 350),
                onTileLoaded: (r) {
                  setState(() {
                    _statusText =
                        '📍 ${r.displayName.split(',').first.trim()}  '
                        '(${r.latitude.toStringAsFixed(3)}, '
                        '${r.longitude.toStringAsFixed(3)})';
                  });
                },
                onError: (e) => setState(() => _statusText = '❌ $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
