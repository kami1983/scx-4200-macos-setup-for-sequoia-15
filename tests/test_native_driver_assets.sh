#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
INSTALLER="$ROOT/install_scx4200_native_driver.sh"
PPD="$ROOT/native/ppd/scx4200.ppd"
FILTER="$ROOT/native/bin/rastertoqpdl"

assert_file() {
    test -f "$1" || { echo "missing: $1" >&2; exit 1; }
}

assert_contains() {
    grep -Fq "$2" "$1" || { echo "missing '$2' in $1" >&2; exit 1; }
}

assert_not_contains() {
    ! grep -Fq "$2" "$1" || { echo "unexpected '$2' in $1" >&2; exit 1; }
}

assert_file "$INSTALLER"
assert_file "$PPD"
assert_file "$FILTER"

bash -n "$INSTALLER"
assert_contains "$PPD" '*Product: "(SCX-4200)"'
assert_contains "$PPD" '*ModelName: "Samsung SCX-4200"'
assert_contains "$PPD" '*QPDL QPDLVersion: "1"'
assert_contains "$PPD" '*cupsFilter: "application/vnd.cups-raster 0 /Library/Printers/QPDL/rastertoqpdl"'
assert_contains "$INSTALLER" 'macOS 27'
assert_contains "$INSTALLER" 'arm64'
assert_contains "$INSTALLER" 'Samsung_SCX-4200'
assert_contains "$INSTALLER" 's/.*：//p'
assert_not_contains "$INSTALLER" 'rastertosec'
assert_not_contains "$INSTALLER" 'SCX-4300 Series'

cupstestppd -q "$PPD"
test "$(lipo -archs "$FILTER")" = "arm64"

echo "native driver asset contract: PASS"
