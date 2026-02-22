# flutter_taerae_example

This example shows how to:

- create and mutate an embedded graph with `TaeraeGraphController`.
- render current nodes/edges in Flutter UI.
- run BFS shortest-path queries locally (`alice -> seoul`).
- call `TaeraeFlutter.getPlatformVersion()` as a platform-channel smoke check.

## Run

```bash
flutter pub get
flutter run
```

## End-User CRUD/Search Flow

This example now includes a full in-app flow for data creation, retrieval,
update, and deletion:

1. `Node CRUD` section:
   add or update node by `id`, optional `labels`, and JSON `properties`.
2. `Node Search` section:
   filter by `id`, `label`, and property key/value.
3. Search result cards:
   tap edit icon to load the selected node into the node form for update.
4. `Edge CRUD` section:
   add or update edge by `id`, `from`, `to`, optional `type`, and JSON
   `properties`.
5. `Current Graph` section:
   inspect all nodes/edges and perform inline edit/delete actions.

## Input Tips

- `labels`: comma-separated text, for example `Person, Employee`.
- `properties`: JSON object, for example `{"name":"Alice","team":"core"}`.
- Search property values support `string`, `number`, `bool`, `null`, JSON array,
  and JSON object.
