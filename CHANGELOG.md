# Changelog

All notable changes to Hemp0x Commander are documented here.

## [1.3.0] (WIP) - 2026-01-08

### Added
- Sort and Hide assets function added
- Added "Hide Asset" toggle to asset cards
- Added "Show Hidden" global toggle in toolbar
- Implemented drag-and-drop reordering for assets
- Persisted asset order and visibility settings to `app_settings.json`

### New Features
- **Major Code Base Refactor** - Complete modularization of backend and frontend for stability and maintainability
- **Snapshot Installer** - Install blockchain snapshots from `.7z` archives directly in the app
  - Stops node, extracts, and restarts automatically
  - Smart detection of nested folder structures
- **Asset UX/UI Enhancements**
  - Grouped assets with sub-asset hierarchy in list view
  - Enhanced detail modal with metadata (supply, reissuable, IPFS, block height)
  - Navigation arrows to flip through assets
  - Sub-asset creation support in ISSUE tab
  - IPFS hash field for asset metadata
  - **Smart Balance Formatting** - Auto-shortens large numbers (1.2M, 500K) and strips trailing zeros
  - **Streamlined Forms** - Compact layouts for CREATE/TRANSFER with click-to-close backdrops
  - **Asset Modals** - Unified Modal UX for Sub-Assets, NFTs, Transfer, and Reissue
  - **Navigation** - Preserves Asset Card background when opening actions
  - **Accessibility** - Fixed label associations and backdrop interactions
  - **Compact NFT Modal** - Optimized layout merging fields
  - **UI Polish** - Fixed layout gaps and button spacing in Asset Card
  - **Asset Governance Safety**
    - **Hold-to-Lock** - "Lock Supply" requires a 10-second hold with visual countdown to prevent accidental locking
    - **Smart Reissue** - "Reissue" button is disabled (greyed out) for locked assets
    - **Styled Alerts** - Critical actions (Transfer, Lock) now use persistent, styled alerts instead of browser popups
    - **Future-Ready UI** - Added UI placeholders for upcoming Governance & Dividend features

### Wallet & Encryption
- Streamlined new wallet creation with proper node stop/start
- Restore Wallet opens file picker directly
- Encryption warnings and completion modal
- Address sorting by Label/Balance on Receive page

### Tools
- **Network Tab** - Peer management and diagnostics
- **Peer Protection** - Auto-bans outdated nodes (<4.7.0)
- **Ping & Port Tools** - Built-in network diagnostics
- **Key Management** - Export/import private keys with balance display
- **Open Folder** - Now opens file explorer directly (fixed)

### UI Polish
- Dark neon theme refinements
- Center-aligned modals with proper z-index
- Processing overlay with spinner
- Responsive breakpoints for various screen sizes

### Backend
- New commands for network, keys, and snapshot handling
- Updated seed node to 147.93.185.184
- `sevenz-rust` integration for 7z extraction

### Cleanup
- Memory leak fixes
- Dead code removal
- Proper lifecycle cleanup

### Build & Infrastructure
- **Portable Linux Binaries** - Fully static builds (Boost/BDB embedded) for cross-distro compatibility (Nobara/Ubuntu 18.04+)
- Updated bundled binaries to latest static version

---

## [1.2.0] - 2026-01-05

### Added
- **Tools Tab** - Console, Wallet controls, Config editor, Logs viewer
- **Coin Control** - UTXO selection for advanced sends
- **Two-Panel Layouts** - Send and Assets views redesigned for desktop
- **Wallet Controls** - Encrypt, Unlock, Lock from the UI
- **TX Previews** - Preview cards before sending

### Changed
- Assets view got sticky headers and better action panels
- Default window size now 1080x720
- Refined aesthetics and typography
- Tab switching now forces remount for cleaner state

### Fixed
- Windows: `hemp.conf` now uses `daemon=0`
- Fixed z-index issues with tabs under overlays
- Added validation for asset issuance
- Fixed scroll overflow in Receive/Assets
- Fixed footer clipping on small displays

---

## [1.1.0] - 2025-12-30

### Added
- Bundled hemp0xd and hemp0x-cli into AppImage/Deb/Rpm
- Updated app icon to Hemp Logo (512px)
- Auto-generated secure RPC credentials
- "Hide Balance" toggle
- Fixed Linux file picker dialogs

---

## [0.1.0] - 2025-12-23
- Initial release
