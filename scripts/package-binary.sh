#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
BIN_PATH="${BIN_PATH:-$ROOT/.build/release/seldon}"
ARCH="${ARCH:-$(uname -m)}"
OUT_NAME="${OUT_NAME:-seldon-macos-${ARCH}}"

mkdir -p "$DIST_DIR"
cp "$BIN_PATH" "$DIST_DIR/$OUT_NAME"
chmod +x "$DIST_DIR/$OUT_NAME"

echo "$DIST_DIR/$OUT_NAME"
