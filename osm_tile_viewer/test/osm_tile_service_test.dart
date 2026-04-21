import 'package:flutter_test/flutter_test.dart';
import 'package:osm_tile_viewer/osm_tile_viewer.dart';

void main() {
  group('OsmTileService – coordinate helpers', () {
    final service = const OsmTileService();

    test('lonToTileX – prime meridian at zoom 0 is tile 0', () {
      expect(service.lonToTileX(0, 0), 0);
    });

    test('lonToTileX – west edge at zoom 1', () {
      expect(service.lonToTileX(-180, 1), 0);
    });

    test('lonToTileX – east edge at zoom 1', () {
      // 179.999... rounds down to 1
      expect(service.lonToTileX(179.9999, 1), 1);
    });

    test('latToTileY – equator at zoom 1 is tile 1', () {
      expect(service.latToTileY(0, 1), 1);
    });

    test('lonToTileX / latToTileY – London at zoom 10', () {
      // London ≈ 51.5°N, -0.12°E
      final x = service.lonToTileX(-0.12, 10);
      final y = service.latToTileY(51.5, 10);
      // Known values: x=511, y=340
      expect(x, 511);
      expect(y, 340);
    });
  });

  group('OsmTileController', () {
    test('starts in idle state', () {
      final controller = OsmTileController();
      expect(controller.status, OsmTileStatus.idle);
      expect(controller.result, isNull);
      expect(controller.errorMessage, isNull);
      controller.dispose();
    });

    test('clear() resets to idle', () {
      final controller = OsmTileController();
      // Simulate a completed state by calling clear (nothing to reset here,
      // just validate the method works without errors)
      controller.clear();
      expect(controller.status, OsmTileStatus.idle);
      controller.dispose();
    });

    test('isEmpty checks are consistent', () {
      final controller = OsmTileController();
      expect(controller.isLoading, isFalse);
      expect(controller.hasResult, isFalse);
      expect(controller.hasError, isFalse);
      controller.dispose();
    });
  });
}
