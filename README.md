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
    <img src="https://img.shields.io/badge/WEBSITE-hemp0x.com-success?style=for-the-badge&logo=globe&logoColor=black&labelColor=black" alt="Website" />
  </a>
  <a href="https://github.com/beyondcr/hemp0x-commander/releases">
    <img src="https://img.shields.io/badge/DOWNLOAD-v1.2-lightgrey?style=for-the-badge&logo=windows&logoColor=black&labelColor=black" alt="Download" />
  </a>
  <a href="https://discord.gg/hemp0x">
    <img src="https://img.shields.io/badge/DISCORD-JOIN_DEVS-5865F2?style=for-the-badge&logo=discord&logoColor=white&labelColor=black" alt="Discord" />
  </a>
</div>

<br />

![Dashboard Preview](docs/images/dashboard.png)

---

## ⚡ Overview

**Hemp0x Commander** brings the power of the Hemp0x blockchain to your desktop. Built with **Tauri v2** (Rust) and **Svelte 5**, it combines the security of a local full node with the ease of use of a modern web application.

> **⚠️ STATE: HEAVY ACTIVE DEVELOPMENT**
>
> This software is currently in **Beta (v1.2)**. While functional, it is evolving rapidly.
> *   Expect bugs.
> *   Expect UI changes.
> *   **USE AT YOUR OWN RISK.** We are not responsible for lost funds or data.
> *   Always backup your `wallet.dat`.

### ✨ Key Features

| Feature | Description | Status |
| :--- | :--- | :--- |
| **🪙 Asset Management** | Issue assets and view ownership. Metadata support coming soon. | 🚧 **In Testing** |
| **🛡️ Privacy First** | Connects to your own local `hemp0xd` node via authenticated RPC. | ✅ Stable |
| **🔧 Coin Control** | (Advanced) Manually select which UTXOs to spend. Optimize privacy. | ✅ Stable |
| **🖥️ Node Control** | Start/Stop daemon, view sync, peer count, and network difficulty. | ✅ Stable |
| **🔒 Encryption** | AES-256 local wallet encryption. | ✅ Stable |

---

## 📸 Visual Tour

<div align="center">

| System Status | About & Credits |
|:---:|:---:|
| <img src="docs/images/system.png" width="100%" /> | <img src="docs/images/about.png" width="100%" /> |

</div>

---

## 📦 Installation

**Windows** & **Linux** supported.

### Windows
1.  Navigate to the **[Releases Page](https://github.com/beyondcr/hemp0x-commander/releases)**.
2.  Download the **Installer** (`.exe`) or the **Portable Version** (`.zip`).
3.  Launch `Hemp0x Commander.exe`.

### Linux
1.  Download the **AppImage** from **[Releases](https://github.com/beyondcr/hemp0x-commander/releases)**.
2.  `chmod +x Hemp0x_Commander_*.AppImage`
3.  ./Launch

---

## 💀 Contributing & Bugs

This application is merely a **Visual Shell** interacting with the core `hemp0xd` binaries. If the shell breaks, your coins are safe in the daemon.

**Found a glitch? Want a feature?**
Don't keep it to yourself.
*   **Report it** on the [Hemp0x Discord](https://discord.gg/hemp0x).
*   **Fix it** and submit a PR.
*   **Break it** and tell us how you did it.

*We build together.*

---

## 🛠️ Building from Source

**Prerequisites:** Node.js v18+, Rust Stable.

**Critical Note:** You must manually place `hemp0xd` and `hemp0x-cli` into the `src-tauri/` folder before building.

```bash
npm install
npm run tauri build
```

---

<div align="center">
  <p>Powered by the <b>Hemp0x Blockchain</b>.</p>
  <a href="https://hemp0x.com">hemp0x.com</a>
</div>
