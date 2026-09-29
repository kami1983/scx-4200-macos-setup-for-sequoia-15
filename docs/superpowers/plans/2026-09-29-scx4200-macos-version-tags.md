# Samsung SCX-4200 macOS Version Tags Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

Goal: Upgrade the repository with a native arm64 macOS 27+ installation path while preserving the existing legacy path under a separate macOS-version tag.

Architecture: Keep the current installer and DMG untouched for v1.0.0-macos-13-26-legacy. Add a separate native installer, exact SCX-4200 PPD, and arm64 QPDL filter under the current line, then tag that snapshot as v2.0.0-macos-27-native-arm64. The native installer validates the host, reuses or discovers the USB URI, installs into /Library/Printers/QPDL, and configures the existing Samsung_SCX-4200 queue.

Tech Stack: macOS shell scripts, CUPS (lpadmin, lpinfo, lpstat, cupstestppd), Mach-O arm64 binary, Git tags.

## Global Constraints

- v1.0.0-macos-13-26-legacy must point to the pre-upgrade commit f2bab2b.
- v2.0.0-macos-27-native-arm64 targets macOS 27+ on Apple Silicon and does not require Rosetta.
- The native path must use the SCX-4200 PPD and native rastertoqpdl, not rastertosec or the old SCX-4300 PPD.
- The queue name remains Samsung_SCX-4200.
- The native installer must reuse an existing queue URI or discover an exact SCX-4200 USB URI; it must not hard-code the current printer serial number.
- Do not change or delete the legacy installer, DMG, or legacy behavior.
- Do not add scanner functionality.
- Do not push tags or commits to GitHub during this task.
- Each implementation change must have a test or a documented device-only verification boundary.

---

### Task 1: Add the native asset contract test

Files:
- Create: tests/test_native_driver_assets.sh

Interfaces:
- Consumes: repository-relative native installer, native PPD, native arm64 filter, and README files.
- Produces: a single shell command that exits 0 only when the v2 native asset contract is satisfied.

- [ ] Step 1: Write the failing test

Create an executable shell test with these assertions:

```bash
#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
INSTALLER="$ROOT/install_scx4200_native_driver.sh"
PPD="$ROOT/native/ppd/scx4200.ppd"
FILTER="$ROOT/native/bin/rastertoqpdl"

assert_file() { test -f "$1" || { echo "missing: $1" >&2; exit 1; }; }
assert_contains() { grep -Fq "$2" "$1" || { echo "missing '$2' in $1" >&2; exit 1; }; }
assert_not_contains() { ! grep -Fq "$2" "$1" || { echo "unexpected '$2' in $1" >&2; exit 1; }; }

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
assert_not_contains "$INSTALLER" 'rastertosec'
assert_not_contains "$INSTALLER" 'SCX-4300 Series'

cupstestppd -q "$PPD"
test "$(lipo -archs "$FILTER")" = "arm64"

echo "native driver asset contract: PASS"
```

- [ ] Step 2: Run the test to verify it fails for the intended reason

Run:

```bash
bash tests/test_native_driver_assets.sh
```

Expected: FAIL because the native installer, PPD, and filter have not been added. This establishes that the test is not passing trivially on the legacy repository.

- [ ] Step 3: Commit the failing test

```bash
git add tests/test_native_driver_assets.sh
git commit -m "test: define native SCX-4200 driver contract"
```

### Task 2: Add native driver assets and installer

Files:
- Create: native/bin/rastertoqpdl (copy the verified arm64 SpliX/QPDL filter)
- Create: native/ppd/scx4200.ppd (copy the OpenPrinting SpliX SCX-4200 PPD and set the absolute installed filter path)
- Create: native/NOTICE.md (source, license, and SHA-256 provenance)
- Create: install_scx4200_native_driver.sh
- Test: tests/test_native_driver_assets.sh

Interfaces:
- Consumes: the native binary and PPD bundled under native/.
- Produces: an installed filter at /Library/Printers/QPDL/rastertoqpdl, an installed PPD at /Library/Printers/QPDL/scx4200.ppd, and an enabled Samsung_SCX-4200 CUPS queue.

- [ ] Step 1: Add the exact native PPD and filter provenance

Copy the already verified arm64 filter from /tmp/samsung-scx4300-arm64-20260928/bin/rastertoqpdl and the exact SCX-4200 PPD from /tmp/openprinting-splix-20260928/ppd/scx4200.ppd. Change only the PPD filter line to:

```text
*cupsFilter: "application/vnd.cups-raster 0 /Library/Printers/QPDL/rastertoqpdl"
```

Record these values in native/NOTICE.md:

```text
Filter: rastertoqpdl
Source: SpliX / OpenPrinting-derived QPDL driver; arm64 build used by the native tag
License: GNU GPL v2
SHA-256: 9b4504271a6fe1eb8f69a7cd8b2573cd49e82cd484fe204b0902cff470bf7520
PPD source: OpenPrinting SpliX ppd/scx4200.ppd
```

- [ ] Step 2: Implement the minimal native installer

Implement install_scx4200_native_driver.sh with set -euo pipefail and these operations in order:

1. Resolve SCRIPT_DIR, native/bin/rastertoqpdl, and native/ppd/scx4200.ppd from the script location.
2. Require root and fail with sudo guidance if not root.
3. Read sw_vers -productVersion and reject a major version below 27.
4. Require uname -m to be arm64.
5. Run cupstestppd -q on the bundled PPD and require lipo -archs to return exactly arm64.
6. Create /Library/Printers/QPDL, copy the filter with mode 755 and owner root:wheel, and copy the PPD with mode 644 and owner root:wheel.
7. Read the existing queue URI from lpstat -v Samsung_SCX-4200 when available. If it is empty, select the first lpinfo -v URI whose complete line contains scx-4200 case-insensitively. If no URI is found, exit before changing the CUPS queue and explain how to reconnect the printer.
8. Run lpadmin -p Samsung_SCX-4200 -D "Samsung SCX-4200 Series" -L "Local" -v "$URI" -P "$PPD" -E, then cupsenable and cupsaccept for the queue.
9. Print lpstat -p Samsung_SCX-4200 and a one-page lp test command.

The script must not reference the old DMG, rastertosec, Samsung SCX-4300 Series, or the current printer serial number.

- [ ] Step 3: Run the asset test to verify it passes

Run:

```bash
bash tests/test_native_driver_assets.sh
```

Expected: native driver asset contract: PASS, exit code 0, and no cupstestppd error.

- [ ] Step 4: Commit the native assets and installer

```bash
git add native install_scx4200_native_driver.sh tests/test_native_driver_assets.sh
git commit -m "feat: add native arm64 SCX-4200 driver path"
```

### Task 3: Document tag selection and native installation

Files:
- Modify: README.md

Interfaces:
- Consumes: the two tag names and the native installer from Task 2.
- Produces: a README whose first decision is macOS version/architecture selection, followed by reproducible native installation and verification commands.

- [ ] Step 1: Add the version selection table

Add a top-level section with this exact mapping:

```markdown
| macOS | Apple Silicon | Use |
|---|---|---|
| 13–26 | Intel or Apple Silicon | v1.0.0-macos-13-26-legacy |
| 27+ | Apple Silicon | v2.0.0-macos-27-native-arm64 |
```

State that the repository name is unchanged, users should check out the matching tag, and the native path does not need Rosetta.

- [ ] Step 2: Add the native installation and verification commands

Document:

```bash
git clone git@github.com:kami1983/scx-4200-macos-setup-for-sequoia-15.git
cd scx-4200-macos-setup-for-sequoia-15
git checkout v2.0.0-macos-27-native-arm64
sudo ./install_scx4200_native_driver.sh

lpstat -p Samsung_SCX-4200
file /Library/Printers/QPDL/rastertoqpdl
lipo -archs /Library/Printers/QPDL/rastertoqpdl
cupstestppd -q /Library/Printers/QPDL/scx4200.ppd
echo "native SCX-4200 test" | lp -d Samsung_SCX-4200
```

Keep the existing legacy instructions available under a clearly labeled legacy section and state that the legacy tag is the stable fallback for macOS 13–26.

- [ ] Step 3: Run documentation and shell checks

Run:

```bash
git diff --check
bash -n install_scx4200_driver.sh install_scx4200_native_driver.sh
bash tests/test_native_driver_assets.sh
```

Expected: exit code 0 for every command.

- [ ] Step 4: Commit the documentation

```bash
git add README.md
git commit -m "docs: document macOS driver tag selection"
```

### Task 4: Verify installation and create the two local tags

Files:
- Modify: CUPS system state through the native installer (device verification only)
- Create: Git tags v1.0.0-macos-13-26-legacy and v2.0.0-macos-27-native-arm64

Interfaces:
- Consumes: the native installer and test suite from Tasks 2–3.
- Produces: a verified native queue and two non-overlapping local release tags.

- [ ] Step 1: Verify the clean legacy baseline before tagging

Run:

```bash
test -z "$(git diff f2bab2b -- install_scx4200_driver.sh SamsungPrinterDrivers.dmg)"
git diff f2bab2b -- README.md
git tag --list 'v1.0.0-macos-13-26-legacy' 'v2.0.0-macos-27-native-arm64'
```

Expected: the legacy installer and DMG have no diff; README only contains the
new tag-selection/native documentation; and neither requested tag already exists.

- [ ] Step 2: Run the full repository-local checks

Run:

```bash
bash -n install_scx4200_driver.sh install_scx4200_native_driver.sh
bash tests/test_native_driver_assets.sh
git diff --check
```

Expected: all commands exit 0.

- [ ] Step 3: Run the native installer on the connected printer

Run:

```bash
sudo ./install_scx4200_native_driver.sh
lpstat -p Samsung_SCX-4200
echo "Samsung SCX-4200 native tag test" | lp -d Samsung_SCX-4200
lpstat -W completed -o Samsung_SCX-4200
```

Expected: queue is enabled/accepting, the job reaches completed, and the existing physical printer produces the page. If physical output cannot be observed, report CUPS completion separately from the device-output boundary.

- [ ] Step 4: Tag the preserved legacy commit

```bash
git tag -a v1.0.0-macos-13-26-legacy f2bab2b -m "Legacy Samsung driver for macOS 13-26"
```

- [ ] Step 5: Tag the native commit

```bash
git tag -a v2.0.0-macos-27-native-arm64 HEAD -m "Native arm64 SCX-4200 driver for macOS 27+"
```

- [ ] Step 6: Verify tag topology and final diff

Run:

```bash
git show-ref --tags
test "$(git rev-list -n 1 v1.0.0-macos-13-26-legacy)" = f2bab2b
test "$(git rev-list -n 1 v2.0.0-macos-27-native-arm64)" = "$(git rev-parse HEAD)"
git status --short --branch
```

Expected: the legacy tag resolves to f2bab2b, the native tag resolves to the current implementation commit, and the working tree is clean. Do not push unless separately authorized.
