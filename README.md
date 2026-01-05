# Hemp0x Commander

<div align="center">
  <a href="https://hemp0x.com">
    <img src="src/assets/hemp0xgit.png" alt="Hemp0x Logo" width="160" />
  </a>

  <h3>The Official Graphical Interface for the Hemp0x Blockchain</h3>

  <p>
    A secure, non-custodial, and cross-platform dashboard for managing your node and assets.
  </p>

  <br />

  <a href="https://hemp0x.com">
    <img src="https://img.shields.io/badge/WEBSITE-hemp0x.com-success?style=for-the-badge&logo=globe" alt="Website" />
  </a>
  <a href="https://github.com/beyondcr/hemp0x-commander/releases">
    <img src="https://img.shields.io/badge/DOWNLOAD-v1.2-blue?style=for-the-badge&logo=windows" alt="Download" />
  </a>
  <a href="docs/BUILDING.md">
    <img src="https://img.shields.io/badge/BUILD-GUIDES-orange?style=for-the-badge&logo=rust" alt="Build Guides" />
  </a>
</div>

<br />

![Dashboard Preview](docs/images/dashboard.png)

---

## ⚡ Overview

**Hemp0x Commander** brings the power of the Hemp0x blockchain to your desktop. Built with **Tauri v2** (Rust) and **Svelte 5**, it combines the security of a local full node with the ease of use of a modern web application.

Unlike web wallets, **Hemp0x Commander is non-custodial**. Your private keys and `wallet.dat` never leave your device. You are in complete control of your funds and data.

### ✨ Key Features

| Feature | Description |
| :--- | :--- |
| **🪙 Asset Management** | Issue, reissue, and transfer unique Hemp0x assets directly from the UI. Visualize your portfolio with rich metadata. |
| **🛡️ Privacy First** | Connects to your own local `hemp0xd` node via authenticated RPC. No third-party servers track your transactions. |
| **🔧 Coin Control** | (Advanced) Manually select which UTXOs to spend. Optimize for privacy or reduce transaction fees by consolidating inputs. |
| **🖥️ Node Control** | Start, stop, and monitor your blockchain daemon seamlessly. View sync progress, peer count, and network difficulty in real-time. |
| **🔒 Encryption** | Secures your wallet with AES-256 encryption. Unlock only when necessary to sign transactions. |

---

## 📸 visual Tour

<div align="center">

| System Status | About & Credits |
|:---:|:---:|
| <img src="docs/images/system.png" width="100%" /> | <img src="docs/images/about.png" width="100%" /> |

</div>

---

## 📦 Installation

We support **Windows** and **Linux** natively.

### Windows
1.  Navigate to the **[Releases Page](https://github.com/beyondcr/hemp0x-commander/releases)**.
2.  Download the **Installer** (`.exe`) or the **Portable Version** (`.zip`).
3.  Running the installer will set up shortcuts automatically. If using the Portable version, simply extract and run `Hemp0x Commander.exe`.

### Linux
1.  Download the **AppImage** from **[Releases](https://github.com/beyondcr/hemp0x-commander/releases)**.
2.  Make the file executable:
    ```bash
    chmod +x Hemp0x_Commander_*.AppImage
    ```
3.  Launch the application. It runs on most distributions (Nobara, Ubuntu, Fedora, Arch).

---

## 🛠️ Building from Source

Developers can build the Commander from source code.

**Prerequisites:**
- **Node.js**: v18+
- **Rust**: Latest Stable
- **Binaries**: You must manually place `hemp0xd` and `hemp0x-cli` into the `src-tauri/` folder before building, as they are not included in the git repository.

```bash
# 1. Install Dependencies
npm install

# 2. Run in Development Mode
npm run tauri dev

# 3. Build Release Artifacts
npm run tauri build
```

For detailed instructions on cross-compiling for Windows on Linux, see [docs/BUILDING.md](docs/BUILDING.md).

---

## ⚙️ Data Locations

The application stores your blockchain data, `wallet.dat`, and configuration files in standard OS locations:

- **Windows:** `%APPDATA%\Hemp0x`
- **Linux:** `~/.hemp0x`

> **Note:** Always backup your `wallet.dat` to a safe location before upgrading or performing major changes.

---

<div align="center">
  <p>Powered by the <b>Hemp0x Blockchain</b>.</p>
  <a href="https://hemp0x.com">Visit Hemp0x.com</a>
</div>
