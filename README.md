# Hemp0x Commander

<div align="center">

```
██╗  ██╗███████╗███╗   ███╗██████╗  ██████╗ ██╗  ██╗
██║  ██║██╔════╝████╗ ████║██╔══██╗██╔═████╗╚██╗██╔╝
███████║█████╗  ██╔████╔██║██████╔╝██║██╔██║ ╚███╔╝ 
██╔══██║██╔══╝  ██║╚██╔╝██║██╔═══╝ ████╔╝██║ ██╔██╗ 
██║  ██║███████╗██║ ╚═╝ ██║██║     ╚██████╔╝██╔╝ ██╗
╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚═╝      ╚═════╝ ╚═╝  ╚═╝
```

<img src="src/assets/hemp0xgit.png" width="120" />

<br>

<a href="https://hemp0x.com">
  <img src="https://img.shields.io/badge/OFFICIAL-WEBSITE-00ff00?style=for-the-badge&logo=globe&logoColor=black&labelColor=black" alt="Website">
</a>
<a href="https://github.com/beyondcr/hemp0x-commander/releases">
  <img src="https://img.shields.io/badge/DOWNLOAD-v1.2-00ff00?style=for-the-badge&logo=windows&logoColor=black&labelColor=black" alt="Download">
</a>
<a href="docs/BUILDING.md">
  <img src="https://img.shields.io/badge/BUILD-GUIDES-00ff00?style=for-the-badge&logo=rust&logoColor=black&labelColor=black" alt="Build">
</a>

</div>

---

![Dashboard Preview](docs/images/dashboard.png)

## ⚡ SYSTEM_OVERVIEW

**Hemp0x Commander** is a terminal-inspired, non-custodial interface for the Hemp0x Blockchain. Built with **Tauri v2** and **Svelte 5**, it merges the raw power of the command line with the usability of a modern GUI. 

`>_ SECURE SESSION ESTABLISHED`

### [ MODULES_LOADED ]
- **[Asset_Mgmt]**: Issue, reissue, and transfer custom assets natively.
- **[Non_Custodial]**: Private keys remain encrypted locally. `wallet.dat` never leaves your machine.
- **[Coin_Control]**: Manual UTXO selection for precision transaction building.
- **[Node_Link]**: Direct RPC uplink to the bundled `hemp0xd` daemon.
- **[Encrypted]**: AES-256 local wallet encryption.

---

## 📸 VISUAL_LOGS

| [SYSTEM_STATUS] | [ABOUT_KERNEL] |
|:---:|:---:|
| ![System Tab](docs/images/system.png) | ![About Tab](docs/images/about.png) |

---

## 📦 DEPLOYMENT_PROTOCOLS

### :: WINDOWS ::
1.  **Acquire**: Download the **Installer** (`.exe`) or **Portable Zip** from [Releases](https://github.com/beyondcr/hemp0x-commander/releases).
2.  **Execute**: Run `Hemp0x Commander.exe`.

### :: LINUX ::
1.  **Acquire**: Download the **AppImage** from [Releases](https://github.com/beyondcr/hemp0x-commander/releases).
2.  **Permission**: `chmod +x Hemp0x_Commander_*.AppImage`.
3.  **Execute**: `./Hemp0x_Commander_*.AppImage`.

---

## 🛠️ COMPILATION_SOURCE

To compile from source, you must manually bridge the core binaries.

### 1. [INJECT_BINARIES]
To prevent repository bloat, the core daemon is **NOT** tracked in git. You must place them manually:

- **Windows**: `src-tauri/hemp0xd.exe` & `src-tauri/hemp0x-cli.exe`
- **Linux**: `src-tauri/hemp0xd` & `src-tauri/hemp0x-cli`

### 2. [EXECUTE_BUILD]
```bash
npm install
npm run tauri build
```
*(See [BUILDING.md](docs/BUILDING.md) for full schematic)*

---

## ⚙️ DATA_DIRECTORIES

`>_ TARGET_LOCATIONS:`

- **Windows:** `%APPDATA%\Hemp0x`
- **Linux:** `~/.hemp0x`

*CRITIAL WARNING: Always backup `wallet.dat` before executing new versions.*
