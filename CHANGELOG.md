# Changelog

All notable changes to Hemp0x Commander are documented here.

## [1.3.0] - 2026-01-07

### New Stuff
- **Network Tab** - New sub-tab under Tools for network diagnostics and peer management
- **Peer Protection** - Auto-bans nodes running outdated versions (<4.7.0) every 2 minutes
  - "Check Now" button for manual scans
  - View/unban from the ban list
- **Ping & Port Tools** - Built-in ping and TCP port checker (supports hostnames)
- **Key Management** - Export/import private keys with proper wallet unlock flow
  - Shows balance per address so you know which keys matter
  - Select all/none for batch operations
- **Mainnet/Regtest Toggle** - Switch networks from the UI, setting persists

### Backend
- New commands: `ban_old_peers`, `get_ban_list`, `unban_peer`
- New commands: `dump_priv_key`, `import_priv_key`
- New commands: `execute_ping`, `check_open_port`, `get_net_info`
- Updated seed node to 147.93.185.184
- Cleaned up duplicate handler registrations

### UI Overhaul
- **Look & Feel**
  - Polished the dark neon theme throughout
  - Green (#00ff41) accents with glow effects everywhere
  - Better button hover/active states
- **Wallet Tab**
  - Merged Security + Key Management into one panel (was 3, now 2)
  - Less wasted space, cleaner layout
- **Export Keys Modal**
  - Bigger checkboxes (18px), hover glow on rows
  - Balance shown on right side of each address
  - Address truncation for long strings
- **Responsive Design**
  - Width breakpoints at 800px and 600px
  - Height breakpoint at 700px for compact mode
  - Dashboard grid scales down properly
  - Send form stacks vertically on narrow windows
  - Header shrinks on small screens
- **Network Tab UI**
  - Peer protection panel with cyber styling
  - Ping/Port modals with proper success/error states
  - Ban list with unban buttons
- **Modal Polish**
  - Fixed double scrollbar issue
  - Escape key closes modals
  - Dark-themed scrollbars

### Fixes
- Fixed double scrollbar in Export Keys modal
- Fixed memory leak from auto-ban interval (now cleared on unmount)
- Fixed event listener leak for network-changed
- Fixed unbanPeer sending wrong parameter name
- Port checker now resolves hostnames (was IP-only before)

### Cleanup
- Removed ~20 lines of dead CSS (`.dot` class)
- Removed console.log spam and commented debug code
- Removed unused variables
- Added proper lifecycle cleanup

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
