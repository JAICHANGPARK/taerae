# flutter_taerae

Flutter package for using `taerae_core` graph APIs in Flutter apps.

`flutter_taerae` provides:

- `TaeraeGraphController` (`ChangeNotifier`) for Flutter-friendly graph state.
- `TaeraeGraphView` for in-app graph visualization with node/edge tap callbacks.
- `TaeraeFlutter.getPlatformVersion()` for platform-channel smoke testing.
- Re-exported `taerae_core` APIs (graph model/engine, persistence, GraphRAG).

## Why this package

- Flutter-native state integration for graph data via `TaeraeGraphController`.
- No external GraphDB required for on-device graph features.
- Unified import for graph engine, persistence, and GraphRAG building blocks.
- Practical path from local prototype to production app architecture.

## Documentation

- Detailed guide: [`DEVELOPER_GUIDE.md`](DEVELOPER_GUIDE.md)
- API reference: [`API_REFERENCE.md`](API_REFERENCE.md)

## Installation

```yaml
dependencies:
  flutter_taerae: ^0.2.0
```

Local monorepo override example:

```yaml
dependencies:
  flutter_taerae:
    path: ../packages/flutter_taerae

dependency_overrides:
  taerae_core:
    path: ../packages/taerae_core
```

Adjust relative paths to your app directory.

## Quick usage

```dart
import 'package:flutter_taerae/flutter_taerae.dart';

final TaeraeFlutter plugin = TaeraeFlutter();
final String platformVersion =
    await plugin.getPlatformVersion() ?? 'unknown';

final TaeraeGraphController controller = TaeraeGraphController();
controller
  ..upsertNode('n1', labels: const <String>['Person'])
  ..upsertNode('n2', labels: const <String>['Person'])
  ..upsertEdge('e1', 'n1', 'n2', type: 'KNOWS');

final List<String>? path = controller.shortestPathBfs('n1', 'n2');

Widget build(BuildContext context) {
  return SizedBox(
    height: 320,
    child: TaeraeGraphView(
      controller: controller,
      onNodeTap: (TaeraeNode node) => debugPrint('node=${node.id}'),
      onEdgeTap: (TaeraeEdge edge) => debugPrint('edge=${edge.id}'),
    ),
  );
}
```

## Practical CRUD Flow (Flutter App)

For real apps, treat `TaeraeGraphController` as your local graph state layer
and wire user actions directly to controller APIs.

1. `Create` / `Update` node:
   call `upsertNode(id, labels: ..., properties: ...)`.
2. `Create` / `Update` edge:
   call `upsertEdge(id, from, to, type: ..., properties: ...)`.
3. `Search`:
   combine `nodeById`, `nodesByLabel`, `nodesWhereProperty`, `neighbors`,
   and `shortestPathBfs` depending on UX.
4. `Delete`:
   call `removeNode(id)` or `removeEdge(id)`.
5. `Render`:
   bind controller to UI via `AnimatedBuilder` or other `Listenable`-aware
   state wiring. Mutation APIs automatically call `notifyListeners()`.

Reference implementation:

- Example app with end-user CRUD/search UI:
  [`example/lib/main.dart`](example/lib/main.dart)
- Example widget test:
  [`example/test/widget_test.dart`](example/test/widget_test.dart)

Run the example app:

```bash
cd packages/flutter_taerae/example
flutter pub get
flutter run
```
