#!/bin/bash
# Build kernel, Rust proof FFI, and miner inside a CANN toolkit environment.
set -e
cd "$(dirname "$0")/.."

# Locate the CANN toolkit dynamically (9.0.0 / 9.1 / 9.2 / ...).
# Override with CANN_ENV=/path/to/set_env.sh if installed elsewhere.
if [ -z "${CANN_ENV:-}" ]; then
  CANN_ENV=$(ls -d /usr/local/Ascend/cann-*/set_env.sh 2>/dev/null | head -1)
fi
if [ -z "$CANN_ENV" ]; then
  echo "error: CANN toolkit not found." >&2
  echo "  expected: /usr/local/Ascend/cann-*/set_env.sh" >&2
  echo "  install Ascend-cann-toolkit (aarch64), or set CANN_ENV=/path/to/set_env.sh" >&2
  exit 1
fi
CANN_DIR=$(dirname "$CANN_ENV")
# shellcheck disable=SC1090
source "$CANN_ENV"
ASC_MODULES=$(ls -d "$CANN_DIR"/*/tikcpp/ascendc_kernel_cmake/asc_modules 2>/dev/null | head -1)
if [ -z "$ASC_MODULES" ]; then
  echo "error: ASC modules not found under $CANN_DIR (expected */tikcpp/ascendc_kernel_cmake/asc_modules)" >&2
  exit 1
fi
export ASC_MODULES

# Toolchain sanity check (fail early with a readable message).
for tool in gcc cmake cargo; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "error: '$tool' not found in PATH" >&2
    [ "$tool" = cargo ] && echo "  install Rust: https://rustup.rs (aarch64-unknown-linux-gnu)" >&2
    exit 1
  }
done

echo "CANN:   $CANN_DIR"
echo "ASC:    $ASC_MODULES"
# container clock skews ~200s vs the host; touch so make/cmake don't see future mtimes
find . -type f -exec touch {} +

make kernel
make proof
make miner

echo "=== built (fixed rank=128, zero-filled seed-stamped matrices) ==="
ls -la build/
