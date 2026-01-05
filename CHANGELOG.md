# Changelog

All notable changes to the Hemp0x App will be documented here.

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

## Unreleased
- Windows: default `hemp.conf` now uses `daemon=0` on first run to avoid `-daemon` errors.
- Assets: validate issue quantity/units and format args before running CLI.
- Tools: console command list now fills the prompt; Enter runs the command.
- Initial Tauri + Svelte scaffold.
- Dashboard UI with glass slab aesthetic.
- Create/Commander/Dev tab shell with slide transitions.
- Docs skeleton in `docs/`.
- Dark green neon palette, centered title bar, and wider drop-down tabs.
- Mobile-first layout, black background, neon green/purple palette, and shield logo.
- Fixed tab view alignment and added animated line background.
- CRT-inspired neon terminal layout with card system and data-heavy dashboard.
- Restored dropdown nav, sliding create/dev overlays, and updated logo usage.
- Glassy OLED HUD layout, commander sub-tabs, and staged asset backdrops.
- Cleaned palette to green/white, removed backdrops, widened layout, and retuned tabs.
- Increased UI density and glow contrast for tighter, higher-pop panels.
- Added Tauri dashboard backend commands and live UI binding.
- Wired Send/Receive/Assets actions to daemon via Tauri commands.
- Standardized hemp.conf usage with explicit datadir/conf for CLI/daemon.
- Added wallet encrypt/unlock/lock actions to match Commander flow.
- Added bin path resolution for dev builds and improved CLI error reporting.
- Fixed Tauri detection for live data binding in app views.
- Show offline placeholders instead of stale dashboard data.
- Expanded binary discovery for dev layout.
- Increased default window size and tightened activity table columns.
- Adjusted default window size to 1080x720 for broader laptop fit.
- Added uniform UI scale when the window is smaller than 1080x720.
- Allow slight upscale (up to 1.1x) to reduce unused space on larger windows.
- Increased activity row size and added footer padding to prevent clipping.
- Rebalanced activity sizing and footer spacing after scaling feedback.
- Increased activity typography and gave the table more vertical space.
- Increased dashboard typography, spaced activity columns, and added a styled wallet prompt.
- Tightened wallet status layout and fixed modal a11y warnings.
- Locked window resize to a 1080x720 aspect ratio.
- Added safe-margin scaling to prevent footer clipping at startup.
- Implemented Tools tab (console, wallet, config, logs) and improved Send/Receive flows.
- Removed aspect ratio lock to restore tab interactions; fixed remaining label a11y warnings.
- Removed nav click delegation and added debug logging for tab switching.
- Raised nav z-index and removed the temporary active-tab debug readout.
- Added a two-panel Send layout with a live transaction preview card.
- Improved Assets view with a nested action panel, sticky headers, and a scrollable status box.
- Hardened Receive/Assets scrolling so long lists stay inside their panels.
- Raised top-bar stacking context and ensured tabs remain clickable over overlays.
- Keyed tab rendering to force view remount on tab change.
- Simplified Send view to a single glass panel and removed the preview section.
- Added a stronger glass panel style and applied it across non-dashboard tabs.
- Tightened Send layout to use no more than half the screen and improved Receive scrolling.
- Rebalanced Send into a two-panel layout with a dedicated wallet status card.
