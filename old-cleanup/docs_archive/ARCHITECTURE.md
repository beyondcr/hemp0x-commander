# Architecture

Hemp0x App is split into a UI layer and a local backend layer:

1) Svelte UI (frontend)
   - Pure UI and client state.
   - Calls backend commands through Tauri.
   - No direct access to daemon or CLI binaries.

2) Tauri backend (Rust)
   - Process control for hemp0xd and hemp0x-cli.
   - JSON-RPC client for core data and wallet ops.
   - CLI fallback for recovery or RPC unavailability.
   - Local auth token for UI requests.

3) Hemp0x Core
   - hemp0xd daemon.
   - hemp0x-cli for CLI actions and recovery.

Data flow:
UI -> Tauri command -> RPC (primary) or CLI fallback -> hemp0xd

Security and updates:
- No self-modifying scripts.
- Update manifest with hash verification.
- Optional wallet signature verification for releases.
