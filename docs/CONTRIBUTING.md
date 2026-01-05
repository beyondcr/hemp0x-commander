# Contributing to Hemp0x Commander

We welcome contributions from the community. Use this guide to set up your development environment and understand the system architecture.

## 🛠️ Development Setup

### Prerequisites
- **Node.js**: v18 (LTS) or higher.
- **Rust**: Latest stable toolchain via `rustup`.
- **Git**: Version control.
- **Windows Users**: 
  - Visual Studio 2022 Build Tools (Desktop development with C++ workload).
  - WebView2 Runtime.
- **Linux Users**:
  - `webkit2gtk-4.0` or `4.1`, `libssl-dev`, `libgtk-3-dev`.

### Quick Start
1.  **Install Frontend Deps**:
    ```bash
    npm install
    ```
2.  **Run UI Only** (Fast Hot-Reload):
    ```bash
    npm run dev
    ```
    *Access via http://localhost:5173*.
3.  **Run Full App** (Backend + UI):
    ```bash
    npm run tauri dev
    ```
    *This compiles the Rust backend and launches the desktop window.*

---

## 🏗️ System Architecture

The application follows a secure, split-process model:

### 1. Frontend Layer (Svelte 5)
- Handles all user interactions and state management.
- Zero direct access to the filesystem or binaries.
- Communicates exclusively via Tauri Commands.

### 2. Backend Layer (Tauri/Rust)
- **Sidecar Manager**: Controls the lifecycle of `hemp0xd` and `hemp0x-cli`.
- **RPC Client**: Proxies requests to the local `hemp0xd` RPC interface with authentication.
- **Security**: Enforces permissions via `capabilities` configuration.

### 3. Core Layer (C++)
- **hemp0xd**: The actual blockchain node (runs as a child process).
- **hemp0x-cli**: Fallback interface for recovery operations.

**Data Flow:**
`UI -> Rust Backend -> Authenticated RPC -> Hemp0x Daemon`

---

## 📝 Pull Request Guidelines
- **Clean Code**: Remove unused imports and console logs (`console.log`) before committing.
- **Atomic Commits**: Keep changes focused on a single feature or fix.
- **No Secrets**: Never commit private keys, `.env` files with real credentials, or `wallet.dat` backups.
