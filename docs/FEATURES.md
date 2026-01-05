# System Features

Hemp0x Commander provides a comprehensive interface for the Hemp0x blockchain. Only key capabilities are listed below.

## 🪙 Core Wallet & Banking
- **Dashboard:** Real-time overview of HEMP balance, asset valuation, and network status.
- **Transactions:** High-speed send/receive with address book integration.
- **Coin Control (Advanced):**
  - Granular `listunspent` visualization.
  - Manual UTXO selection for transaction construction.
  - "Lock/Unlock" coins to prevent accidental spending.
  - Privacy optimization via input selection.

## 💎 Asset Management (Under Development)
- **Visual Asset Browser:** View balances for Root, Sub, and Unique assets.
- **Issuance:** Create new assets with custom metadata and supply.
- **Transfers:** Send assets to any Hemp0x address with attached memos.
- **Reissuance:** Adjust supply or update metadata (requires Owner Token).

## 🖥️ Node Commander
- **Lifecycle Management:** Start, stop, and restart the embedded `hemp0xd` node.
- **Network Monitor:**(coming soon) Visual graph of peer connections and block height synchronization.
- **Console:** Direct RPC terminal for executing raw `hemp0x-cli` commands (e.g., `getblock`, `getpeerinfo`).
- **Logs:** Real-time streaming of `debug.log` for troubleshooting.

## 🔒 Security & Architecture
- **Local-Only:** No keys are ever sent to a remote server.
- **Encryption:** Industry-standard wallet encryption (AES-256).
- **Isolation:** The UI runs in a sandboxed WebView, while sensitive cryptographic operations are handled by the Rust backend or the `hemp0xd` binary.
## Report bugs or request features at https://github.com/hemp0x/hemp0x-commander/issues or at https://hemp0x.com or the hemp0x discord server.