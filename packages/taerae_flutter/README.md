# taerae_flutter

Flutter package for using `taerae_core` graph APIs in Flutter apps.

`taerae_flutter` provides:

- `TaeraeGraphController` (`ChangeNotifier`) for Flutter-friendly graph state.
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
  taerae_flutter: ^0.1.0
```

Local monorepo override example:

```yaml
dependencies:
  taerae_flutter:
    path: ../packages/taerae_flutter

dependency_overrides:
  taerae_core:
    path: ../packages/taerae_core
```

Adjust relative paths to your app directory.

## Quick usage

```dart
import 'package:taerae_flutter/taerae_flutter.dart';

final TaeraeFlutter plugin = TaeraeFlutter();
final String platformVersion =
    await plugin.getPlatformVersion() ?? 'unknown';

final TaeraeGraphController controller = TaeraeGraphController();
controller
  ..upsertNode('n1', labels: const <String>['Person'])
  ..upsertNode('n2', labels: const <String>['Person'])
  ..upsertEdge('e1', 'n1', 'n2', type: 'KNOWS');

final List<String>? path = controller.shortestPathBfs('n1', 'n2');
```
