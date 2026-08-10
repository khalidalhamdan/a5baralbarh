#!/usr/bin/env bash
set -euo pipefail

echo "=== CI gate runner ==="

if ! command -v node >/dev/null 2>&1; then
  echo "FAIL: node runtime not found in this environment."
  echo "Cannot execute typecheck/test/build locally until Node is available."
  echo "Required commands still to run in a Node-enabled environment:"
  echo "  pnpm typecheck"
  echo "  pnpm test"
  echo "  pnpm build"
  exit 1
fi

if ! command -v pnpm >/dev/null 2>&1; then
  echo "FAIL: pnpm not found"
  exit 1
fi

set -x
pnpm typecheck
pnpm test
pnpm build
set +x

echo "PASS: typecheck, test, and build completed"
