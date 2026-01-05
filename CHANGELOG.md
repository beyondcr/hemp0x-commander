# Changelog

All notable changes to the Hemp0x App will be documented here.

## [1.2.0] - 2026-01-05
### Added
- **Tools Tab:** Implemented full Tools suite including Console, Wallet controls, Config editor, and Logs.
- **UTXO Management:** Added Coin Control features for granular UTXO selection.
- **Two-Panel Layouts:** Redesigned Send and Assets views with split-panel layouts for better desktop usability.
- **Wallet Controls:** Added Encrypt, Unlock, and Lock actions directly in the UI.
- **Live Previews:** Added transaction preview cards for Send flow.

### Changed
- **Assets UI:** Improved Assets view with sticky headers, nested action panels, and dedicated status box.
- **Window Management:** Adjusted default window size to 1080x720 with safe-margin scaling (removed strict aspect lock).
- **Visuals:** Refined glass aesthetics, typography density, and stacking contexts for modal overlays.
- **Performance:** Optimized tab switching with forced view remounts for cleaner state.

### Fixed
- **Windows:** Fixed `hemp.conf` generation to use `daemon=0` to prevent startup errors.
- **Navigation:** Fixed z-index issues causing tabs to be unclickable under overlays.
- **Validation:** Added proper validation for asset issuance quantities and units.
- **Scrolling:** Hardened scroll containers in Receive/Assets to prevent content overflow.
- **Scaling:** Fixed footer clipping issues on smaller displays.

## [1.1.0] - 2025-12-30
### Added
- **Linux Portability:** Bundled `hemp0xd` and `hemp0x-cli` sidecars into the AppImage/Deb/Rpm (Self-Contained).
- **Icons:** Updated application icon to official Hemp Logo (512px).
- **Security:** Added automated secure RPC credential generation (Random User/Pass).
- **UI:** Added "Hide Balance" toggle and updated asset issuance cost.
- **Fixes:** Resolved Linux file picker dialog issues using native Tauri dialogs.

## [0.1.0] - 2025-12-23
### Added
- Initial Release
