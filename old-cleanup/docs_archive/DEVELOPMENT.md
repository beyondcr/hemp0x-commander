# Development

Prerequisites:
- Node.js (LTS)
- Rust (rustup)
- Git
- Visual Studio Build Tools with C++ workload (Windows)
- WebView2 Runtime (Windows)

Install commands (Windows):
- `winget install --id OpenJS.NodeJS.LTS -e`
- `winget install --id Rustlang.Rustup -e`
- `winget install --id Git.Git -e`
- `winget install --id Microsoft.VisualStudio.2022.BuildTools -e`
- `winget install --id Microsoft.EdgeWebView2Runtime -e`

Run the UI only (fast preview):
1) `npm install`
2) `npm run dev`
3) Open the URL shown by Vite (default http://localhost:5173)

Run the full desktop app:
1) `tauri dev`

Troubleshooting: link.exe not found
- Install the Visual C++ workload for Build Tools.
- In Visual Studio Installer: Modify -> Build Tools -> "Desktop development with C++".
- Ensure MSVC v143 and Windows SDK are selected.

Tauri rebuild notes:
- Frontend changes hot-reload.
- Backend (Rust) changes require a rebuild of the Tauri side.
