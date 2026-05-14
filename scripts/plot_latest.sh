#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./scripts/plot_latest.sh [--no-open] [--no-serve]

Generates AFL++ plots for the latest run under outputs/ and serves them locally.

Environment:
  OUTPUT_DIR   AFL++ output root. Default: ./outputs
  PLOT_ROOT    Plot output root. Default: ./plots
  IMAGE_NAME   Docker image used when afl-plot is not on PATH. Default: libsixel-fuzzer
  PORT         Preferred local server port. Default: 8080
USAGE
}

open_browser=1
serve=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-open)
      open_browser=0
      ;;
    --no-serve)
      serve=0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd -- "$script_dir/.." && pwd)"
output_dir="${OUTPUT_DIR:-"$root_dir/outputs"}"
plot_root="${PLOT_ROOT:-"$root_dir/plots"}"
image_name="${IMAGE_NAME:-libsixel-fuzzer}"
preferred_port="${PORT:-8080}"

if [[ ! -d "$output_dir" ]]; then
  echo "No AFL++ output directory found: $output_dir" >&2
  exit 1
fi

latest_run="$(
  OUTPUT_DIR="$output_dir" python3 - <<'PY'
import os
from pathlib import Path

root = Path(os.environ["OUTPUT_DIR"])
best_run = None
best_mtime = -1

for stats in root.glob("*/*/fuzzer_stats"):
    try:
        mtime = stats.stat().st_mtime
    except OSError:
        continue
    run = stats.parents[1]
    if mtime > best_mtime:
        best_mtime = mtime
        best_run = run

if best_run is not None:
    print(best_run)
PY
)"

if [[ -z "$latest_run" ]]; then
  echo "No AFL++ fuzzer_stats files found under: $output_dir" >&2
  exit 1
fi

mapfile -t state_dirs < <(
  LATEST_RUN="$latest_run" python3 - <<'PY'
import os
from pathlib import Path

run = Path(os.environ["LATEST_RUN"])
dirs = sorted(p.parent for p in run.glob("*/fuzzer_stats"))
for d in dirs:
    print(d)
PY
)

if [[ ${#state_dirs[@]} -eq 0 ]]; then
  echo "No AFL++ state directories found under latest run: $latest_run" >&2
  exit 1
fi

run_name="$(basename "$latest_run")"
plot_dir="$plot_root/latest"
mkdir -p "$plot_root"
rm -rf "$plot_dir"
mkdir -p "$plot_dir"

echo "Latest AFL++ run: $latest_run"
echo "State directories:"
printf '  %s\n' "${state_dirs[@]}"
echo "Writing plots to: $plot_dir"

if command -v afl-plot >/dev/null 2>&1; then
  afl-plot "${state_dirs[@]}" "$plot_dir"
else
  docker_args=(docker run --rm --user "$(id -u):$(id -g)" -v "$root_dir:/work" "$image_name" afl-plot)
  container_state_dirs=()
  for dir in "${state_dirs[@]}"; do
    case "$dir" in
      "$root_dir"/*)
        container_state_dirs+=("/work/${dir#"$root_dir"/}")
        ;;
      *)
        echo "Cannot map AFL++ state directory into Docker container: $dir" >&2
        echo "Install afl-plot locally, or keep OUTPUT_DIR inside this repository." >&2
        exit 1
        ;;
    esac
  done
  "${docker_args[@]}" "${container_state_dirs[@]}" "/work/plots/latest"
fi

latest_url_path="latest/"

if [[ "$serve" -eq 0 ]]; then
  echo "Plot generated: $plot_dir/index.html"
  exit 0
fi

port="$(
  PREFERRED_PORT="$preferred_port" python3 - <<'PY'
import os
import socket

start = int(os.environ["PREFERRED_PORT"])
for port in range(start, start + 100):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        try:
            sock.bind(("127.0.0.1", port))
        except OSError:
            continue
        print(port)
        break
else:
    raise SystemExit("No free local port found")
PY
)"

url="http://127.0.0.1:${port}/${latest_url_path}"
echo "Serving plots at: $url"

if [[ "$open_browser" -eq 1 ]]; then
  if command -v open >/dev/null 2>&1; then
    open "$url" >/dev/null 2>&1 || true
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 || true
  fi
fi

cd "$plot_root"
exec python3 -m http.server "$port" --bind 127.0.0.1
