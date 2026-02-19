#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
BIN_PATH="${BIN_PATH:-$ROOT/.build/release/seldon}"
ARCH="${ARCH:-$(uname -m)}"
STAGING_NAME="${STAGING_NAME:-seldon-macos-${ARCH}-with-tools}"
TAR_NAME="${TAR_NAME:-${STAGING_NAME}.tar.gz}"

STAGING_DIR="$DIST_DIR/$STAGING_NAME"
mkdir -p "$STAGING_DIR/tools"

cp "$BIN_PATH" "$STAGING_DIR/seldon"
chmod +x "$STAGING_DIR/seldon"
cp "$ROOT/tools.example.yaml" "$STAGING_DIR/tools.example.yaml"
cp -R "$ROOT/tools/." "$STAGING_DIR/tools/"
find "$STAGING_DIR/tools" -name '*.py' -type f -exec chmod +x {} +

tar -C "$DIST_DIR" -czf "$DIST_DIR/$TAR_NAME" "$STAGING_NAME"

echo "$DIST_DIR/$TAR_NAME"
