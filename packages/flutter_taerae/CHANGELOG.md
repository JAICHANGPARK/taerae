## 0.1.1

- Optimize `TaeraeGraphController` by caching sorted node/edge snapshots.
- Expand controller behavior coverage, including mutation/no-op notification paths.
- Raise `lib/` statement coverage to 100%.

## 0.1.0

- Promote plugin template into a usable Flutter package for `taerae_core`.
- Add local `taerae_core` dependency and re-export core graph APIs.
- Add `TaeraeGraphController` (`ChangeNotifier`) with graph read/write helpers.
- Add JSON import/export helpers on the controller.
- Update example app to demonstrate graph mutations and shortest-path display.
- Expand unit tests for platform interface behavior and controller behavior.
- Add `API_REFERENCE.md` with plugin-available API inventory.
