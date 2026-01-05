# Hemp0x Commander

<p align="center">
  <img src="src/assets/logonew.png" alt="Hemp0x Commander" width="180" />
</p>

<p align="center">
  <b>The Official Graphical Interface for the Hemp0x Blockchain</b>
  <br />
  <a href="https://hemp0x.com">Website</a> • 
  <a href="https://github.com/beyondcr/hemp0x-commander/releases">Download</a> • 
  <a href="docs/BUILDING.md">Build Guides</a>
</p>

---

![Dashboard Preview](docs/images/dashboard.png)

## ⚡ Overview

**Hemp0x Commander** is a secure, non-custodial wallet and node manager built with **Tauri v2** (Rust) and **Svelte 5**. It is designed for speed, privacy, and ease of use, running natively on Windows and Linux.

### Key Features
- **🪙 Asset Management:** Issue, reissue, and transfer custom Hemp0x assets natively.
- **🛡️ Non-Custodial:** Your private keys never leave your machine (`wallet.dat` stays local).
- **🔧 Advanced Coin Control:** Manual UTXO selection for precision transaction building.
- **🖥️ Node Management:** Built-in control for the bundled `hemp0xd` background service.
- **🔒 Encrypted Communication:** Interacts securely with your local node via RPC.

---

## 📸 Screenshots

| System Status | About & Credits |
|:---:|:---:|
| ![System Tab](docs/images/system.png) | ![About Tab](docs/images/about.png) |

---

## 📦 Installation

### Windows
1.  Download the **Installer** (`.exe`) or **Portable Zip** from [Releases](https://github.com/beyondcr/hemp0x-commander/releases).
2.  Run the installer or extract the zip.
3.  Launch `Hemp0x Commander.exe`.

### Linux
1.  Download the **AppImage** from [Releases](https://github.com/beyondcr/hemp0x-commander/releases).
2.  Make executable: `chmod +x Hemp0x_Commander_*.AppImage`.
3.  Run: `./Hemp0x_Commander_*.AppImage`.

---

## 🛠️ Building from Source

To compile the application yourself, you will need **Rust**, **Node.js**, and the **Hemp0x Core Binaries**.

### 1. Place Core Binaries
The application requires the blockchain daemon (`hemp0xd`) and CLI (`hemp0x-cli`) to function. You must compile these or download them and place them in the `src-tauri` directory.

- **Windows:**
  - `src-tauri/hemp0xd.exe`
  - `src-tauri/hemp0x-cli.exe`

- **Linux:**
  - `src-tauri/hemp0xd`
  - `src-tauri/hemp0x-cli`

### 2. Build Commands
```bash
# Install dependencies
npm install

# Run in Development Mode (Hot Reload)
npm run tauri dev

# Build for Production
npm run tauri build
```

See [docs/BUILDING.md](docs/BUILDING.md) for detailed compilation instructions.

---

## ⚙️ Data Locations
- **Windows:** `%APPDATA%\Hemp0x`
- **Linux:** `~/.hemp0x`

This folder contains your `wallet.dat`, `hemp.conf`, and blockchain data. **Always backup your wallet.dat!**
