import 'package:flutter/material.dart';
import 'models/osm_tile_result.dart';
import 'osm_tile_controller.dart';
import 'osm_tile_service.dart';
import 'widgets/osm_search_bar.dart';
import 'widgets/osm_interactive_map.dart';

/// The main widget: a search bar with live suggestions + an interactive OSM map.
class OsmTileViewer extends StatefulWidget {
  final OsmTileController? controller;
  final int zoom;
  final double mapHeight;
  final String searchHint;
  final void Function(OsmTileResult result)? onTileLoaded;
  final void Function(String error)? onError;
  final EdgeInsetsGeometry padding;
  final Duration searchDebounce;

  const OsmTileViewer({
    super.key,
    this.controller,
    this.zoom = 15,
    this.mapHeight = 420,
    this.searchHint = 'Search for a place…',
    this.onTileLoaded,
    this.onError,
    this.padding = const EdgeInsets.all(16),
    this.searchDebounce = const Duration(milliseconds: 400),
  });

  @override
  State<OsmTileViewer> createState() => _OsmTileViewerState();
}

class _OsmTileViewerState extends State<OsmTileViewer> {
  late final OsmTileController _controller;
  late final bool _ownsController;
  final _service = const OsmTileService();

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? OsmTileController(service: _service);
    _controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    if (_controller.hasResult) widget.onTileLoaded?.call(_controller.result!);
    if (_controller.hasError) widget.onError?.call(_controller.errorMessage!);
    setState(() {});
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search bar + suggestions dropdown
          OsmSearchBar(
            hint: widget.searchHint,
            debounce: widget.searchDebounce,
            onSuggest: (q) => _service.suggest(q),
            onSelected: (s) => _controller.goToLocation(
              lat: s.latitude,
              lng: s.longitude,
              displayName: s.displayName,
              zoom: widget.zoom,
            ),
            onFreeSearch: (q) => _controller.search(q, zoom: widget.zoom),
          ),
          const SizedBox(height: 12),
          // Status / map area
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_controller.status) {
      case OsmTileStatus.idle:
        return _Placeholder(mapHeight: widget.mapHeight);

      case OsmTileStatus.loading:
        return SizedBox(
          height: widget.mapHeight,
          child: const Center(child: CircularProgressIndicator()),
        );

      case OsmTileStatus.error:
        return _ErrorPanel(
          message: _controller.errorMessage ?? 'Unknown error',
          mapHeight: widget.mapHeight,
        );

      case OsmTileStatus.success:
        final result = _controller.result!;
        return _ResultPanel(
          result: result,
          service: _service,
          mapHeight: widget.mapHeight,
          zoom: widget.zoom,
        );
    }
  }
}

// ── Sub-panels ───────────────────────────────────────────────────────────────

class _Placeholder extends StatelessWidget {
  final double mapHeight;
  const _Placeholder({required this.mapHeight});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: mapHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECF0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined,
              size: 56,
              color: Colors.blueGrey.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            'Search for any place to explore the map',
            style: TextStyle(
              color: Colors.blueGrey.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  final double mapHeight;
  const _ErrorPanel({required this.message, required this.mapHeight});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: mapHeight,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 40),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  final OsmTileResult result;
  final OsmTileService service;
  final double mapHeight;
  final int zoom;

  const _ResultPanel({
    required this.result,
    required this.service,
    required this.mapHeight,
    required this.zoom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Place info row
        Row(
          children: [
            const Icon(Icons.location_pin, color: Colors.red, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                result.displayName.split(',').first.trim(),
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${result.latitude.toStringAsFixed(4)}, '
              '${result.longitude.toStringAsFixed(4)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Interactive map
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: OsmInteractiveMap(
            latitude: result.latitude,
            longitude: result.longitude,
            initialZoom: zoom,
            height: mapHeight,
            service: service,
          ),
        ),
      ],
    );
  }
}
