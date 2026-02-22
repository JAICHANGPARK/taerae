#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKIP_EXAMPLES=false

usage() {
  cat <<'EOF'
Usage: ./scripts/dev-checks.sh [--skip-examples]

Runs standard local development checks for this monorepo:
1) bootstrap dependencies for core + flutter packages
2) bootstrap example dependencies (optional)
3) run analyze + test for core and flutter packages
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' is required but was not found in PATH." >&2
    exit 1
  fi
}

run_in() {
  local relative_dir="$1"
  shift

  echo "==> (cd ${relative_dir} && $*)"
  (
    cd "${ROOT_DIR}/${relative_dir}"
    "$@"
  )
}

bootstrap_examples() {
  if [[ ! -d "${ROOT_DIR}/examples" ]]; then
    return
  fi

  echo "==> Bootstrapping examples"

  local example_dir
  while IFS= read -r -d '' example_dir; do
    if [[ -f "${example_dir}/pubspec.yaml" ]]; then
      local relative_dir="${example_dir#"${ROOT_DIR}/"}"
      echo "==> (cd ${relative_dir} && dart pub get)"
      (
        cd "${example_dir}"
        dart pub get
      )
    fi
  done < <(find "${ROOT_DIR}/examples" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
}

for arg in "$@"; do
  case "${arg}" in
    --skip-examples)
      SKIP_EXAMPLES=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument '${arg}'" >&2
      usage
      exit 1
      ;;
  esac
done

require_cmd dart
require_cmd flutter

run_in packages/taerae_core dart pub get
run_in packages/flutter_taerae flutter pub get

if [[ "${SKIP_EXAMPLES}" == "false" ]]; then
  bootstrap_examples
else
  echo "==> Skipping example bootstrap (--skip-examples)"
fi

run_in packages/taerae_core dart analyze
run_in packages/taerae_core dart test
run_in packages/flutter_taerae flutter analyze
run_in packages/flutter_taerae flutter test

echo "All checks passed."
