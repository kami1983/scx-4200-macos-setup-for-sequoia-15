# Native QPDL driver provenance

The native filter is `rastertoqpdl`, an arm64 build of the SpliX/OpenPrinting
QPDL driver used for the SCX-4200/SCX-4300 print engine family.

- Source: [OpenPrinting SpliX](https://github.com/OpenPrinting/splix)
- License: GNU GPL v2
- Filter SHA-256: `9b4504271a6fe1eb8f69a7cd8b2573cd49e82cd484fe204b0902cff470bf7520`
- PPD source: OpenPrinting SpliX `ppd/scx4200.ppd`
- Installed filter path: `/Library/Printers/QPDL/rastertoqpdl`
- Installed PPD path: `/Library/Printers/QPDL/scx4200.ppd`

The binary is included so macOS 27+ Apple Silicon users do not need a compiler,
Homebrew, or Rosetta to install the printing path. The source project and GPL
license remain the authoritative references for the filter implementation.
