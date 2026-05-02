#!/usr/bin/env bash
# build.sh — compile the booba WASM artifact and stage the example directory.
#
# Usage:
#   cd booba && ./build.sh
#
# Requirements:
#   - Go 1.21+ (GOOS=js GOARCH=wasm support)
#   - Internet access on first run to `go install` the booba-wasm-build tool

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

EXAMPLE_DIR="$SCRIPT_DIR/example"

# ---------------------------------------------------------------------------
# 1. Install booba-wasm-build
#    go-booba ships a thin wrapper around `go build` that patches the missing
#    js/wasm stubs (tty_js.go, signals_js.go) directly into the
#    charm.land/bubbletea/v2 module cache before compiling, working around the
#    upstream issue: https://github.com/charmbracelet/bubbletea/issues/1410
# ---------------------------------------------------------------------------
BOOBA_VERSION="$(go list -m -f '{{.Version}}' github.com/NimbleMarkets/go-booba 2>/dev/null || echo "latest")"
echo "==> Installing booba-wasm-build@${BOOBA_VERSION} ..."
go install "github.com/NimbleMarkets/go-booba/cmd/booba-wasm-build@${BOOBA_VERSION}"

# ---------------------------------------------------------------------------
# 2. Build the WASM binary
# ---------------------------------------------------------------------------
echo "==> Building example/booba.wasm ..."
booba-wasm-build -o "$EXAMPLE_DIR/booba.wasm" .

# ---------------------------------------------------------------------------
# 3. Copy wasm_exec.js from the Go runtime
#    Location changed between Go releases:
#      <= 1.20:  $GOROOT/misc/wasm/wasm_exec.js
#      >= 1.21:  $GOROOT/lib/wasm/wasm_exec.js
# ---------------------------------------------------------------------------
GOROOT="$(go env GOROOT)"
if [[ -f "$GOROOT/lib/wasm/wasm_exec.js" ]]; then
    WASM_EXEC_SRC="$GOROOT/lib/wasm/wasm_exec.js"
elif [[ -f "$GOROOT/misc/wasm/wasm_exec.js" ]]; then
    WASM_EXEC_SRC="$GOROOT/misc/wasm/wasm_exec.js"
else
    echo "ERROR: wasm_exec.js not found under \$GOROOT ($GOROOT)" >&2
    exit 1
fi
echo "==> Copying wasm_exec.js from $WASM_EXEC_SRC ..."
cp "$WASM_EXEC_SRC" "$EXAMPLE_DIR/wasm_exec.js"

# ---------------------------------------------------------------------------
# 4. Done
# ---------------------------------------------------------------------------
echo ""
echo "Build complete.  Serve the example with:"
echo ""
echo "    cd example && python3 -m http.server"
echo ""
echo "Then open http://localhost:8000 in your browser."
