<script>
  import { onMount, tick } from "svelte";
  import { fly, fade } from "svelte/transition";
  import { core } from "@tauri-apps/api";
  import { emit } from "@tauri-apps/api/event";
  import { save, open, ask } from "@tauri-apps/plugin-dialog";
  import { open as shellOpen } from "@tauri-apps/plugin-shell";

  let activeSubTab = "CONSOLE";
  let tauriReady = false;

  // Toast System
  let toastMsg = "";
  let toastType = "info"; // info, error, success
  let toastTimer;

  function showToast(msg, type = "info") {
    clearTimeout(toastTimer);
    toastMsg = msg;
    toastType = type;
    toastTimer = setTimeout(() => {
      toastMsg = "";
    }, 3000);
  }

  // Console
  let selectedCommand = "";
  let cmdLine = "";
  let shellMode = false;

  // Persistent Props
  export let consoleOutput = "";
  export let consoleHistory = [];
  export let isNodeOnline = false; // Received from App.svelte

  let historyIndex = -1;
  $: cmdPlaceholder = shellMode ? "type a shell command" : "command args";
  let consoleRef;

  const commands = [
    "getinfo",
    "help",
    "setaccount",
    "getblockchaininfo",
    "getnetworkinfo",
    "getwalletinfo",
    "getpeerinfo",
    "getmininginfo",
    "getmempoolinfo",
    "listassets",
    "listmyassets",
    "listbanned",
    "listtransactions",
    "listunspent",
    "listaddressgroupings",
    "listreceivedbyaddress",
    "validateaddress",
    "getnewaddress",
    "sendtoaddress",
    "stop",
    "backupwallet",
    "encryptwallet",
    "walletpassphrase",
    "walletlock",
    "getdifficulty",
    "getnetworkhashps",
    "uptime",
    "verifymessage",
    "signmessage",
    "issue",
    "transfer",
    "reissue",
  ];

  async function appendOutput(text) {
    if (!text) return;
    consoleOutput = consoleOutput ? `${consoleOutput}\n${text}` : text;
    await tick();
    if (consoleRef) {
      consoleRef.scrollTop = consoleRef.scrollHeight;
    }
  }

  async function runCommand() {
    if (!tauriReady) return;
    try {
      const line = cmdLine.trim();
      if (!line) {
        appendOutput("Enter a command to run");
        showToast("No command entered", "error");
        return;
      }

      // SAFETY CHECK: Prevent 'generate' on Mainnet (Freezes RPC)
      if (networkMode === "mainnet" && line.startsWith("generate")) {
        appendOutput(
          "⚠️ SAFETY ERROR: 'generate' creates blocks in the foreground.",
        );
        appendOutput(
          "On Mainnet, this command will wait indefinitely for a block, freezing the application.",
        );
        appendOutput(
          "To mine on Mainnet, please use: setgenerate true <threads>",
        );
        showToast("Command Blocked for Safety", "warning");
        return;
      }

      if (consoleHistory[consoleHistory.length - 1] !== line) {
        consoleHistory = [...consoleHistory, line];
      }
      historyIndex = consoleHistory.length;
      let res;
      const prompt = shellMode ? "$" : ">";
      appendOutput(`${prompt} ${line}`);
      if (shellMode) {
        res = await core.invoke("run_shell_command", { command: line });
      } else {
        const splitAt = line.search(/\s/);
        const cmd = splitAt === -1 ? line : line.slice(0, splitAt);
        const cmdArgs = splitAt === -1 ? "" : line.slice(splitAt + 1);
        res = await core.invoke("run_cli_command", {
          command: cmd,
          args: cmdArgs,
        });
      }
      appendOutput(res || "(no output)");
      showToast("Command Executed", "success");
      cmdLine = "";
      selectedCommand = ""; // Reset dropdown so re-selecting same command works
    } catch (err) {
      appendOutput(`Error: ${err}`);
      showToast("Command Failed", "error");
    }
  }

  function handleCommandSelect(event) {
    selectedCommand = event.target.value;
    cmdLine = selectedCommand ? selectedCommand : "";
    // Reset selection so the user can re-select the same command if they want
    if (selectedCommand) {
      setTimeout(() => {
        selectedCommand = "";
      }, 100);
    }
  }

  function toggleShellMode() {
    shellMode = !shellMode;
  }

  function replaceLastToken(value) {
    const idx = cmdLine.search(/\S+$/);
    if (idx === -1) {
      cmdLine = value;
    } else {
      cmdLine = cmdLine.slice(0, idx) + value;
    }
  }

  async function handleAutocomplete() {
    if (shellMode) {
      try {
        const matches = await core.invoke("shell_autocomplete", {
          line: cmdLine,
        });
        if (!matches || matches.length === 0) {
          return;
        }
        if (matches.length === 1) {
          replaceLastToken(matches[0]);
        } else {
          appendOutput(`Matches:\n${matches.join("\n")}`);
        }
      } catch (err) {
        appendOutput(`Error: ${err}`);
      }
      return;
    }

    const input = cmdLine.trim();
    if (!input) return;
    const token = input.split(/\s+/)[0];
    const options = commands.filter((cmd) => cmd.startsWith(token));
    if (options.length === 1) {
      replaceLastToken(options[0]);
    } else if (options.length > 1) {
      appendOutput(`Matches:\n${options.join("\n")}`);
    }
  }

  function handlePromptKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      runCommand();
      return;
    }
    if (event.key === "ArrowUp") {
      if (consoleHistory.length === 0) return;
      event.preventDefault();
      historyIndex = Math.max(0, historyIndex - 1);
      cmdLine = consoleHistory[historyIndex] || "";
      return;
    }
    if (event.key === "ArrowDown") {
      if (consoleHistory.length === 0) return;
      event.preventDefault();
      historyIndex = Math.min(consoleHistory.length, historyIndex + 1);
      cmdLine =
        historyIndex >= consoleHistory.length
          ? ""
          : consoleHistory[historyIndex];
      return;
    }
    if (event.key === "Tab") {
      event.preventDefault();
      handleAutocomplete();
    }
  }

  async function openDataDir() {
    if (!tauriReady) return;
    try {
      const config = await core.invoke("init_config");
      const path = config.data_dir;

      // Use dialog plugin to open a folder browser starting at the data dir
      // This works on Linux where native file managers fail
      await open({
        title: "Hemp0x Data Folder",
        directory: true,
        defaultPath: path,
        multiple: false,
      });
    } catch (err) {
      // If dialog cancelled or fails, show path for manual navigation
      try {
        const config = await core.invoke("init_config");
        showToast(`📂 Path: ${config.data_dir}`, "info");
      } catch {
        showToast("Failed to get path", "error");
      }
    }
  }

  // Data Folder Info
  let dataFolderInfo = {
    path: "--",
    size_display: "--",
    config_exists: false,
    wallet_exists: false,
    folder_exists: false,
  };
  let dataLoading = false;

  async function loadDataInfo() {
    if (!tauriReady) return;
    dataLoading = true;
    try {
      dataFolderInfo = await core.invoke("get_data_folder_info");
    } catch (err) {
      showToast("Failed to load data info", "error");
    }
    dataLoading = false;
  }

  async function backupDataFolder() {
    if (!tauriReady) return;
    try {
      const ts = new Date().toISOString().replace(/[-:T]/g, "").slice(0, 14);
      const filePath = await save({
        title: "Save Data Folder Backup",
        defaultPath: `hemp0x_data_backup_${ts}`,
      });
      if (!filePath) return; // User cancelled
      showToast("Backing up data folder...", "info");
      await core.invoke("backup_data_folder_to", { path: filePath });
      showToast(`Backup saved to: ${filePath}`, "success");
      loadDataInfo();
    } catch (err) {
      showToast(`Backup failed: ${err}`, "error");
    }
  }

  async function createDefaultConfig() {
    if (!tauriReady) return;
    try {
      await core.invoke("create_default_config");
      showToast("Default config created", "success");
      loadDataInfo();
      loadConfig(true);
    } catch (err) {
      showToast(`Failed: ${err}`, "error");
    }
  }

  // ============ UPDATE TAB ============
  const APP_VERSION = "v1.2";
  // TODO: Replace with official update server or Load Balancer
  const UPDATE_SERVER = "https://updates.hemp0x.com/";

  let updateInfo = {
    commanderVersion: APP_VERSION,
    daemonVersion: "--",
    cliVersion: "--",
    daemonFound: false,
    cliFound: false,
  };
  let updateCheckStatus = "Ready to check for updates";
  let isCheckingUpdate = false;

  // React to node coming online to refresh binary status
  $: if (isNodeOnline && tauriReady) {
    loadUpdateInfo();
  }

  async function loadUpdateInfo() {
    if (!tauriReady) return;

    try {
      const binaries = await core.invoke("get_binary_status");
      updateInfo.daemonFound = !!binaries.daemon_exists;
      updateInfo.cliFound = !!binaries.cli_exists;
    } catch {
      updateInfo.daemonFound = false;
      updateInfo.cliFound = false;
    }

    updateInfo.daemonVersion = updateInfo.daemonFound
      ? "Node Offline"
      : "Not Found";
    updateInfo.cliVersion = updateInfo.cliFound ? "Node Offline" : "Not Found";

    if (updateInfo.daemonFound && isNodeOnline) {
      try {
        const info = await core.invoke("run_cli_command", {
          command: "getinfo",
          args: "",
        });
        const parsed = JSON.parse(info);
        updateInfo.daemonVersion = `v${parsed.version || "unknown"}`;
        updateInfo.cliVersion = updateInfo.daemonVersion;
      } catch {
        updateInfo.daemonVersion = "Error";
        updateInfo.cliVersion = "Error";
      }
    }
    updateInfo = updateInfo; // trigger reactivity
  }

  async function checkForUpdates() {
    isCheckingUpdate = true;
    updateCheckStatus = "Checking server...";

    const confirmed = await ask(
      "-Privacy Warning-\nPlease note, this will connect to github.com to check for the latest release.",
      {
        title: "Check for Updates",
        kind: "warning",
        okLabel: "Continue",
        cancelLabel: "Cancel",
      },
    );

    if (!confirmed) {
      isCheckingUpdate = false;
      updateCheckStatus = "Check cancelled.";
      return;
    }

    try {
      // Note: In Tauri, we'd need to use tauri's http client or a backend command
      // For now, this is a placeholder that simulates the check
      const response = await fetch(`${UPDATE_SERVER}version.json`, {
        method: "GET",
        mode: "no-cors",
        signal: AbortSignal.timeout(5000),
      });

      // no-cors doesn't give us response data, so we show placeholder
      updateCheckStatus =
        "⚠️ Server check not yet implemented. Visit Hemp0x.com for latest updates.";
    } catch (err) {
      updateCheckStatus =
        "⚠️ Could not reach update server. Visit Hemp0x.com for latest updates.";
    }

    isCheckingUpdate = false;
    isCheckingUpdate = false;
  }

  async function extractBinaries() {
    if (!tauriReady) return;
    try {
      const selected = await open({
        title: "Select Folder for Binaries",
        directory: true,
        multiple: false,
      });
      if (!selected) return;

      showToast("Extracting binaries...", "info");
      const res = await core.invoke("extract_binaries", {
        targetDir: selected,
      });
      showToast(res, "success");
    } catch (err) {
      showToast(`Extraction Failed: ${err}`, "error");
    }
  }

  // Config
  let configText = "";
  async function loadConfig(silent = false) {
    if (!tauriReady) return;
    try {
      configText = await core.invoke("read_config");
      if (!silent) showToast("Configuration Loaded", "success");
    } catch (err) {
      // If failed, maybe file doesn't exist, just show empty
      if (!silent) showToast("Config missing or empty", "info");
    }
  }

  async function saveConfig() {
    if (!tauriReady) return;
    try {
      await core.invoke("write_config", { contents: configText });
      showToast("Configuration Saved", "success");
    } catch (err) {
      showToast("Failed to save config", "error");
    }
  }

  // Logs
  let logText = "";
  async function refreshLog(silent = false) {
    if (!tauriReady) return;
    try {
      logText = await core.invoke("read_log", { lines: 500 });
      if (!silent) showToast("Logs Refreshed", "success");
    } catch (err) {
      if (!silent) showToast("Failed to read logs", "error");
    }
  }
  function clearLog() {
    logText = "";
    showToast("Log View Cleared", "info");
  }

  // Fallback Save Log (Browser Download)
  function saveLog() {
    try {
      const blob = new Blob([logText], { type: "text/plain" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "hemp0x_debug.log";
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      showToast("Log Downloaded", "success");
    } catch (e) {
      showToast("Save failed", "error");
    }
  }

  // Wallet
  let restorePath = "";
  let passOld = "";
  let passNew = "";
  let passNewConfirm = "";
  let backupBeforeRestore = false;
  let restartAfterRestore = true;
  let backupBeforeNew = false;
  let restartAfterNew = true;

  async function backupWallet() {
    if (!tauriReady) return;
    try {
      const ts = new Date().toISOString().replace(/[-:T]/g, "").slice(0, 14);
      const filePath = await save({
        title: "Save Wallet Backup",
        defaultPath: `hemp0x_wallet_${ts}.dat`,
        filters: [{ name: "Wallet Backup", extensions: ["dat"] }],
      });
      if (!filePath) return; // User cancelled
      await core.invoke("backup_wallet_to", { path: filePath });
      showToast(`Backup Saved: ${filePath}`, "success");
    } catch (err) {
      showToast("Backup Failed", "error");
    }
  }

  async function browseRestore() {
    if (!tauriReady) return;
    try {
      const selected = await open({
        title: "Select Wallet Backup",
        multiple: false,
        filters: [{ name: "Wallet Files", extensions: ["dat", "bak"] }],
      });
      if (selected) {
        restorePath = selected;
      }
    } catch (err) {
      showToast("Browse failed", "error");
    }
  }

  async function restoreWallet() {
    if (!tauriReady) return;
    if (!restorePath) {
      showToast("Enter path to backup file", "error");
      return;
    }
    if (
      !window.confirm(
        backupBeforeRestore
          ? "Restore wallet.dat? Current wallet will be backed up."
          : "Restore wallet.dat without backing up the current wallet?",
      )
    ) {
      return;
    }
    try {
      await core.invoke("restore_wallet", {
        path: restorePath,
        backupExisting: backupBeforeRestore,
        restartNode: restartAfterRestore,
      });
      showToast(
        restartAfterRestore
          ? "Restore Complete. Node restarted."
          : "Restore Complete. Restart Node if needed.",
        "success",
      );
    } catch (err) {
      showToast("Restore Failed", "error");
    }
  }

  async function createNewWallet() {
    if (!tauriReady) return;
    if (
      !window.confirm(
        backupBeforeNew
          ? "Create a fresh wallet? Current wallet will be backed up."
          : "Create a fresh wallet without backing up the current wallet?",
      )
    ) {
      return;
    }
    try {
      await core.invoke("create_new_wallet", {
        backupExisting: backupBeforeNew,
        restartNode: restartAfterNew,
      });
      showToast(
        restartAfterNew
          ? "New Wallet Created. Node restarted."
          : "New Wallet Created. Restart Node if needed.",
        "success",
      );
    } catch (err) {
      showToast("Create Failed", "error");
    }
  }

  async function changePassword() {
    if (!tauriReady) return;
    if (!passOld || !passNew) {
      showToast("Enter old and new passwords", "error");
      return;
    }
    if (passNew !== passNewConfirm) {
      showToast("New passwords do not match", "error");
      return;
    }
    try {
      const res = await core.invoke("change_wallet_password", {
        oldPass: passOld,
        newPass: passNew,
      });
      showToast("Password Updated Successfully", "success");
      passOld = "";
      passNew = "";
      passNewConfirm = "";
    } catch (err) {
      showToast("Password Change Failed", "error");
    }
  }

  // Network Switcher
  let networkMode = "mainnet";
  let showNetworkModal = false;
  let pendingNetworkMode = "";

  async function loadNetworkMode() {
    try {
      networkMode = await core.invoke("get_network_mode");
    } catch {
      networkMode = "mainnet";
    }
  }

  async function changeNetwork(mode) {
    if (!tauriReady) return;
    // Don't do anything if clicking the already active mode
    if (mode === networkMode) return;

    pendingNetworkMode = mode;
    showNetworkModal = true;
  }

  async function confirmNetworkSwitch() {
    showNetworkModal = false;
    const mode = pendingNetworkMode;

    try {
      const res = await core.invoke("set_network_mode", { mode });
      showToast(res, "success");
      networkMode = mode;

      // Emit event for global UI update
      try {
        await emit("network-changed", { mode });
      } catch (e) {
        console.error("Failed to emit network change", e);
      }

      showToast(
        "Config updated. Please restart node manually if required.",
        "info",
      );
    } catch (err) {
      showToast("Failed to switch network: " + err, "error");
    }
    pendingNetworkMode = "";
  }

  function cancelNetworkSwitch() {
    showNetworkModal = false;
    pendingNetworkMode = "";
  }

  onMount(() => {
    tauriReady = typeof core?.isTauri === "function" ? core.isTauri() : false;
    if (tauriReady) {
      loadConfig(true); // Silent start
      refreshLog(true); // Silent start
      loadDataInfo(); // Load data folder info
      loadUpdateInfo(); // Load update tab info
      loadNetworkMode();
    }
  });
</script>

<div class="view-tools">
  <div class="glass-panel panel-strong cyber-panel main-frame">
    <!-- HEADER / TABS -->
    <header class="panel-header no-border">
      <div class="sub-tabs">
        {#each ["CONSOLE", "WALLET", "CONFIG", "DATA", "SYSTEM", "LOGS"] as tab}
          <button
            class="sub-tab-btn"
            class:active={activeSubTab === tab}
            on:click={() => (activeSubTab = tab)}
          >
            {tab}
          </button>
        {/each}
      </div>
      <div class="header-status mono">
        <span class="dot" class:online={tauriReady}></span>
        {tauriReady ? "SYSTEM ONLINE" : "OFFLINE MODE"}
      </div>
    </header>

    <!-- BODY -->
    <div class="tools-body">
      {#key activeSubTab}
        <div class="transition-wrapper" in:fly={{ y: 20, duration: 300 }}>
          {#if activeSubTab === "CONSOLE"}
            <div class="tool-grid console-view">
              <div class="terminal-screen">
                <div class="scanline"></div>
                <textarea
                  class="console-output mono"
                  readonly
                  bind:value={consoleOutput}
                  bind:this={consoleRef}
                ></textarea>
              </div>

              <div class="control-bar compact">
                <div class="field-group grow">
                  <label for="cmd-select">COMMAND LIST</label>
                  <div class="input-wrapper brackets">
                    <select
                      id="cmd-select"
                      bind:value={selectedCommand}
                      on:change={handleCommandSelect}
                      class="input-glass"
                      disabled={shellMode}
                    >
                      <option value="">Select command</option>
                      {#each commands as cmd}
                        <option value={cmd}>{cmd}</option>
                      {/each}
                    </select>
                  </div>
                </div>
                <div class="field-group grow">
                  <label for="cmd-line">ARGUMENT</label>
                  <div class="input-wrapper brackets">
                    <input
                      id="cmd-line"
                      class="input-glass mono"
                      placeholder={cmdPlaceholder}
                      bind:value={cmdLine}
                      on:keydown={handlePromptKeydown}
                    />
                  </div>
                </div>
                <div class="action-group">
                  <button class="cyber-btn" on:click={runCommand}
                    >[ RUN ]</button
                  >
                  <button
                    class="cyber-btn ghost"
                    on:click={() => (consoleOutput = "")}>CLEAR</button
                  >
                  <button class="cyber-btn ghost" on:click={toggleShellMode}>
                    {shellMode ? "SHELL MODE" : "CLI MODE"}
                  </button>
                </div>
              </div>
            </div>
          {:else if activeSubTab === "WALLET"}
            <div class="tool-grid wallet-view">
              <!-- BACKUP COLUMN -->
              <div class="glass-panel panel-soft card">
                <header class="card-header">
                  <span class="card-title">BACKUP & RESTORE</span>
                </header>
                <div class="card-body">
                  <p class="desc">Safeguard your wallet.dat file.</p>
                  <button class="cyber-btn wide" on:click={backupWallet}>
                    [ BACKUP WALLET ]
                  </button>

                  <div class="divider"></div>
                  <div class="toggle-row">
                    <label class="toggle">
                      <input
                        type="checkbox"
                        bind:checked={backupBeforeRestore}
                      />
                      <span>Backup current wallet before restore</span>
                    </label>
                    <label class="toggle">
                      <input
                        type="checkbox"
                        bind:checked={restartAfterRestore}
                      />
                      <span>Restart node after restore</span>
                    </label>
                  </div>

                  <label for="restore-path"
                    >RESTORE FROM FILE (Enter Path)</label
                  >
                  <div class="input-wrapper brackets input-with-btn">
                    <input
                      id="restore-path"
                      class="input-glass mono"
                      placeholder="C:\Path\To\Backup.dat"
                      bind:value={restorePath}
                    />
                    <button
                      class="cyber-btn browse-btn"
                      on:click={browseRestore}>BROWSE</button
                    >
                  </div>
                  <div class="btn-row">
                    <button
                      class="cyber-btn ghost wide"
                      on:click={restoreWallet}>RESTORE</button
                    >
                    <button
                      class="cyber-btn ghost danger wide"
                      on:click={createNewWallet}>NEW WALLET</button
                    >
                  </div>
                  <div class="toggle-row">
                    <label class="toggle">
                      <input type="checkbox" bind:checked={backupBeforeNew} />
                      <span>Backup current wallet before new</span>
                    </label>
                    <label class="toggle">
                      <input type="checkbox" bind:checked={restartAfterNew} />
                      <span>Restart node after new wallet</span>
                    </label>
                  </div>
                </div>
              </div>

              <!-- SECURITY COLUMN -->
              <div class="glass-panel panel-soft card">
                <header class="card-header">
                  <span class="card-title">SECURITY</span>
                </header>
                <div class="card-body">
                  <p class="desc">Update encryption key.</p>
                  <div class="field-group">
                    <input
                      type="password"
                      class="input-glass"
                      placeholder="Current Password"
                      bind:value={passOld}
                    />
                    <input
                      type="password"
                      class="input-glass"
                      placeholder="New Password"
                      bind:value={passNew}
                    />
                    <input
                      type="password"
                      class="input-glass"
                      placeholder="Confirm New"
                      bind:value={passNewConfirm}
                    />
                  </div>
                  <div class="spacer"></div>
                  <button class="cyber-btn wide" on:click={changePassword}>
                    [ UPDATE PASSWORD ]
                  </button>
                </div>
              </div>
            </div>
          {:else if activeSubTab === "CONFIG"}
            <div class="tool-grid full-height">
              <div class="terminal-screen">
                <textarea class="config-editor mono" bind:value={configText}
                ></textarea>
              </div>
              <div class="action-bar-right">
                <button
                  class="cyber-btn ghost"
                  on:click={() => loadConfig(false)}>RELOAD</button
                >
                <button class="cyber-btn" on:click={saveConfig}
                  >[ SAVE CONFIG ]</button
                >
              </div>
            </div>
          {:else if activeSubTab === "LOGS"}
            <!-- LOGS -->
            <div class="tool-grid full-height">
              <div class="terminal-screen">
                <div class="scanline"></div>
                <textarea
                  class="console-output mono"
                  readonly
                  bind:value={logText}
                ></textarea>
              </div>
              <div class="action-bar-right">
                <button class="cyber-btn ghost" on:click={clearLog}
                  >CLEAR VIEW</button
                >
                <button class="cyber-btn" on:click={saveLog}
                  >SAVE LOG (DL)</button
                >
                <button
                  class="cyber-btn ghost"
                  on:click={() => refreshLog(false)}>REFRESH</button
                >
              </div>
            </div>
          {:else if activeSubTab === "DATA"}
            <div class="tool-grid data-view">
              <div class="data-panel">
                <h3 class="data-title">📁 DATA FOLDER</h3>

                <!-- PATH ROW -->
                <div class="path-row">
                  <span class="path-label">PATH:</span>
                  <span class="path-value mono">{dataFolderInfo.path}</span>
                </div>

                <!-- STATUS GRID -->
                <div class="status-grid">
                  <div class="status-item">
                    <span class="status-label">SIZE</span>
                    <span class="status-value"
                      >{dataFolderInfo.size_display}</span
                    >
                  </div>
                  <div class="status-item">
                    <span class="status-label">FOLDER</span>
                    <span
                      class="status-value"
                      class:ok={dataFolderInfo.folder_exists}
                      >{dataFolderInfo.folder_exists
                        ? "EXISTS"
                        : "MISSING"}</span
                    >
                  </div>
                  <div class="status-item">
                    <span class="status-label">CONFIG</span>
                    <span
                      class="status-value"
                      class:ok={dataFolderInfo.config_exists}
                      >{dataFolderInfo.config_exists
                        ? "FOUND"
                        : "MISSING"}</span
                    >
                  </div>
                  <div class="status-item">
                    <span class="status-label">WALLET</span>
                    <span
                      class="status-value"
                      class:ok={dataFolderInfo.wallet_exists}
                      >{dataFolderInfo.wallet_exists
                        ? "FOUND"
                        : "MISSING"}</span
                    >
                  </div>
                </div>

                <!-- ACTION BUTTONS -->
                <div class="data-actions">
                  <button class="cyber-btn" on:click={openDataDir}
                    >OPEN FOLDER</button
                  >
                  <button class="cyber-btn" on:click={backupDataFolder}
                    >BACKUP ALL</button
                  >
                  <button class="cyber-btn ghost" on:click={loadDataInfo}
                    >REFRESH</button
                  >
                </div>

                {#if !dataFolderInfo.config_exists}
                  <div class="config-warning">
                    <span>⚠️ Config file is missing.</span>
                    <button
                      class="cyber-btn small"
                      on:click={createDefaultConfig}>CREATE DEFAULT</button
                    >
                  </div>
                {/if}
              </div>

              <div class="education-section">
                <h3 class="section-title">📖 ABOUT DATA FOLDER</h3>
                <div class="edu-content">
                  <p>
                    The <strong>data folder</strong> contains all Hemp0x blockchain
                    data and wallet information.
                  </p>
                  <ul class="edu-list">
                    <li>
                      <strong>wallet.dat</strong> - Your wallet keys and transaction
                      history. BACK THIS UP!
                    </li>
                    <li>
                      <strong>hemp.conf</strong> - Node configuration file
                    </li>
                    <li>
                      <strong>blocks/</strong> - Downloaded blockchain data
                    </li>
                    <li><strong>chainstate/</strong> - Current UTXO set</li>
                    <li><strong>debug.log</strong> - Node debug log file</li>
                  </ul>
                  <p class="warning-text">
                    ⚠️ Never share your wallet.dat file with anyone.
                  </p>
                </div>
              </div>
            </div>
          {:else if activeSubTab === "SYSTEM"}
            <div class="tool-grid update-view">
              <!-- APP VER INFO -->
              <div class="update-panel">
                <h3 class="update-title">🔄 APP VER INFO</h3>

                <!-- VERSION INFO GRID -->
                <div class="version-grid">
                  <div class="version-card">
                    <span class="version-label">COMMANDER</span>
                    <span class="version-value"
                      >{updateInfo.commanderVersion}</span
                    >
                  </div>
                  <div class="version-card">
                    <span class="version-label">HEMP0XD</span>
                    <span
                      class="version-value"
                      class:ok={updateInfo.daemonFound}
                      >{updateInfo.daemonVersion}</span
                    >
                  </div>
                  <div class="version-card">
                    <span class="version-label">HEMP0X-CLI</span>
                    <span class="version-value" class:ok={updateInfo.cliFound}
                      >{updateInfo.cliVersion}</span
                    >
                  </div>
                </div>

                <!-- BINARY STATUS -->
                <div class="binary-status">
                  <h4 class="section-subtitle">BINARY STATUS</h4>
                  <div class="binary-row">
                    <span class="binary-name mono">hemp0xd</span>
                    <span
                      class="binary-status-badge"
                      class:found={updateInfo.daemonFound}
                    >
                      {updateInfo.daemonFound ? "✓ FOUND" : "✗ MISSING"}
                    </span>
                  </div>
                  <div class="binary-row">
                    <span class="binary-name mono">hemp0x-cli</span>
                    <span
                      class="binary-status-badge"
                      class:found={updateInfo.cliFound}
                    >
                      {updateInfo.cliFound ? "✓ FOUND" : "✗ MISSING"}
                    </span>
                  </div>
                </div>

                <!-- UPDATE CHECK -->
                <div class="update-check-section">
                  <div class="update-actions">
                    <button class="cyber-btn ghost" on:click={extractBinaries}
                      >EXTRACT BINARIES</button
                    >
                    <div
                      class="update-fallback"
                      style="flex: 1; display: flex; align-items: center; justify-content: center;"
                    >
                      <a
                        href="https://hemp0x.com"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        🌐 Visit Hemp0x.com
                      </a>
                    </div>
                  </div>
                </div>

                <!-- CHECKSUM PLACEHOLDER -->
                <div class="checksum-section">
                  <h4 class="section-subtitle">CHECKSUM VERIFICATION</h4>
                  <div class="coming-soon">
                    🔐 Coming Soon: Verify app integrity with Hemp token signed
                    releases
                  </div>
                </div>
              </div>

              <!-- NETWORK SETTINGS -->
              <div class="update-panel">
                <h3 class="update-title" style="margin-bottom: 0.8rem">
                  📡 NETWORK SETTINGS
                </h3>
                <div
                  style="display: flex; justify-content: space-between; align-items: center;"
                >
                  <div
                    class="network-selector"
                    style="display: flex; gap: 0.5rem;"
                  >
                    <button
                      class="cyber-btn small {networkMode === 'mainnet'
                        ? ''
                        : 'ghost'}"
                      on:click={() => changeNetwork("mainnet")}>MAINNET</button
                    >
                    <button
                      class="cyber-btn small {networkMode === 'regtest'
                        ? 'info'
                        : 'ghost'}"
                      on:click={() => changeNetwork("regtest")}>REGTEST</button
                    >
                  </div>
                  <p class="section-subtitle" style="margin: 0;">
                    MODE: <strong
                      class="mono"
                      style="color: var(--color-primary)"
                      >{networkMode.toUpperCase()}</strong
                    >
                  </p>
                </div>
              </div>
            </div>
          {/if}
        </div>
      {/key}
    </div>

    {#if showNetworkModal}
      <div class="modal-overlay" on:click|self={cancelNetworkSwitch}>
        <div class="modal-staged">
          <div class="modal-header">
            <h3>⚠️ RESTART REQUIRED</h3>
          </div>
          <div class="modal-body">
            <p>
              Switching to <strong class="mono"
                >{pendingNetworkMode.toUpperCase()}</strong
              > will modify your configuration.
            </p>
            <p class="desc">
              You must manually stop and restart the application for this to
              take effect.
            </p>
          </div>
          <div class="modal-actions">
            <button class="cyber-btn" on:click={confirmNetworkSwitch}
              >CONFIRM & RESTART</button
            >
            <button class="cyber-btn ghost" on:click={cancelNetworkSwitch}
              >CANCEL</button
            >
          </div>
        </div>
      </div>
    {/if}

    {#if toastMsg}
      <div
        class="toast-popup"
        transition:fade={{ duration: 200 }}
        class:error={toastType === "error"}
        class:success={toastType === "success"}
      >
        {toastMsg}
      </div>
    {/if}
  </div>
</div>

<style>
  .view-tools {
    display: flex;
    flex-direction: column;
    height: 100%;
    gap: 1.2rem;
  }
  .main-frame {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  /* --- TOAST --- */
  .toast-popup {
    position: absolute;
    background: rgba(0, 0, 0, 0.9);
    border: 1px solid var(--color-primary);
    padding: 0.8rem 1.2rem;
    border-radius: 6px;
    z-index: 5000;
    max-width: 300px;
    /* Move to bottom right, away from center/input */
    top: auto;
    left: auto;
    bottom: 80px;
    right: 20px;
    transform: none;

    box-shadow: 0 0 30px rgba(0, 0, 0, 0.8);
    font-family: var(--font-mono);
    font-size: 0.85rem;
    pointer-events: none;
  }
  .toast-popup.error {
    border-color: #ff5555;
    color: #ffaaaa;
    box-shadow: 0 0 30px rgba(255, 80, 80, 0.2);
  }
  .toast-popup.success {
    border-color: #00ff41;
    color: #fff;
    box-shadow: 0 0 30px rgba(0, 255, 65, 0.3);
  }

  /* --- HEADER --- */
  .panel-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: rgba(0, 0, 0, 0.4);
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
  }
  .sub-tabs {
    display: flex;
    gap: 2px;
  }
  .sub-tab-btn {
    background: transparent;
    border: none;
    color: var(--color-muted);
    padding: 1rem 1.5rem;
    font-size: 0.8rem;
    letter-spacing: 1px;
    border-bottom: 2px solid transparent;
    transition: all 0.2s;
  }
  .sub-tab-btn:hover {
    color: #fff;
    background: rgba(255, 255, 255, 0.02);
  }
  .sub-tab-btn.active {
    color: var(--color-primary);
    border-bottom-color: var(--color-primary);
    background: linear-gradient(
      180deg,
      rgba(0, 0, 0, 0) 0%,
      rgba(0, 255, 65, 0.05) 100%
    );
    text-shadow: 0 0 8px rgba(0, 255, 65, 0.4);
  }
  .header-status {
    padding-right: 1.5rem;
    font-size: 0.7rem;
    color: #555;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  .dot {
    width: 8px;
    height: 8px;
    background: #555;
    border-radius: 50%;
  }
  .dot.online {
    background: var(--color-primary);
    box-shadow: 0 0 5px var(--color-primary);
  }

  /* --- BODY --- */
  .tools-body {
    flex: 1;
    overflow-y: auto; /* Enable scrolling */
    padding: 0.5rem;
    padding-bottom: 2.5rem; /* Increased to 2.5rem to lift URL safely above edge */
    position: relative;
    background: rgba(0, 0, 0, 0.2);
  }
  .transition-wrapper {
    height: 100%;
    display: flex;
    flex-direction: column;
  }
  .tool-grid {
    display: flex;
    flex-direction: column;
    gap: 1.2rem;
    height: 100%;
  }
  .tool-grid.wallet-view {
    flex-direction: row; /* Side-by-side for wallet */
    justify-content: center;
    align-items: stretch; /* Ensure same height */
    gap: 2rem;
  }
  .tool-grid.full-height {
    height: 100%;
  }

  /* --- CONSOLE / LOGS --- */
  .terminal-screen {
    flex: 1; /* Grows to fill space */
    display: flex; /* Flex container for textarea */
    flex-direction: column;
    min-height: 400px; /* USER REQUEST: Much taller. */
    height: 100%; /* Force height */
    background: #000;
    border: 1px solid #333;
    padding: 5px;
    border-radius: 12px;
    position: relative;
    overflow: hidden;
    box-shadow: inset 0 0 20px rgba(0, 0, 0, 0.8);
  }
  .terminal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.2rem 0.6rem;
    border-bottom: 1px solid #333;
    background: rgba(0, 0, 0, 0.3);
  }
  .term-title {
    color: #444;
    font-size: 0.7rem;
    font-family: monospace;
    letter-spacing: 1px;
  }
  .clear-btn {
    background: transparent;
    border: none;
    color: #555;
    font-size: 0.7rem;
    cursor: pointer;
    font-family: monospace;
    transition: color 0.2s;
  }
  .clear-btn:hover {
    color: var(--color-primary);
  }
  .console-output,
  .config-editor {
    flex: 1; /* Grow to fill terminal-screen */
    width: 100%;
    height: 100%;
    background: transparent;
    color: #0f0;
    border: none;
    resize: none;
    font-family: "Consolas", monospace;
    font-size: 0.9rem;
    padding: 0.5rem;
    outline: none;
    overflow-y: scroll; /* Force custom scrollbar */
  }
  /* Custom Scrollbar for Terminal */
  .console-output::-webkit-scrollbar,
  .config-editor::-webkit-scrollbar {
    width: 10px;
  }
  .console-output::-webkit-scrollbar-track,
  .config-editor::-webkit-scrollbar-track {
    background: #111;
    border-left: 1px solid #222;
  }
  .console-output::-webkit-scrollbar-thumb,
  .config-editor::-webkit-scrollbar-thumb {
    background: #333;
    border: 1px solid #444;
  }
  .console-output::-webkit-scrollbar-thumb:hover,
  .config-editor::-webkit-scrollbar-thumb:hover {
    background: var(--color-primary);
  }

  .config-editor {
    color: #ccc;
  }
  .grow {
    flex: 1;
    min-height: 0;
  }

  /* --- CONTROLS --- */
  .control-bar {
    display: flex;
    gap: 1rem;
    padding: 1rem;
    background: rgba(255, 255, 255, 0.02);
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 6px;
    align-items: flex-end;
    flex-shrink: 0; /* Don't shrink */
  }
  .control-bar.compact {
    padding: 0.8rem;
  }

  .field-group {
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
  }
  .field-group.grow {
    flex: 1;
  }

  label {
    font-size: 0.65rem;
    color: var(--color-muted);
    letter-spacing: 1px;
  }
  .toggle-row {
    display: flex;
    flex-direction: column;
    gap: 0.6rem;
  }
  .toggle {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    color: #aaa;
    font-size: 0.75rem;
    letter-spacing: 0.5px;
  }
  .toggle input {
    accent-color: var(--color-primary);
  }
  .input-wrapper {
    position: relative;
    width: 100%;
    display: flex;
    gap: 4px;
  }
  .input-glass {
    width: 100%;
    background: rgba(0, 0, 0, 0.4);
    border: 1px solid rgba(255, 255, 255, 0.15);
    color: #fff;
    padding: 0.6rem 0.8rem;
    font-size: 0.9rem;
    border-radius: 4px;
    outline: none;
    transition: all 0.2s;
    font-family: var(--font-mono);
  }
  .input-glass:focus {
    border-color: var(--color-primary);
    box-shadow: 0 0 10px rgba(0, 255, 65, 0.1);
  }

  /* Command Dropdown Styling */
  select.input-glass {
    appearance: none;
    -webkit-appearance: none;
    -moz-appearance: none;
    background: rgba(0, 0, 0, 0.8);
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='%2300ff41'%3E%3Cpath d='M7 10l5 5 5-5z'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right 8px center;
    background-size: 16px;
    padding-right: 28px;
    cursor: pointer;
    color: #9ad7a6;
    font-weight: 500;
    font-size: 0.85rem;
    letter-spacing: 0.5px;
    transition: all 0.15s ease;
  }
  select.input-glass:hover {
    border-color: var(--color-primary);
    background-color: rgba(0, 255, 65, 0.08);
    box-shadow: 0 0 8px rgba(0, 255, 65, 0.15);
  }
  select.input-glass:focus {
    border-color: var(--color-primary);
    box-shadow: 0 0 12px rgba(0, 255, 65, 0.2);
  }
  select.input-glass:disabled {
    opacity: 0.6;
    cursor: not-allowed;
    box-shadow: none;
  }
  select.input-glass option {
    background: #0a0a0a;
    color: #9fbfa7;
    padding: 6px 10px;
    font-size: 0.85rem;
    border-bottom: 1px solid #1a1a1a;
  }
  select.input-glass option:checked {
    background: linear-gradient(90deg, rgba(0, 255, 65, 0.3), transparent);
    font-weight: 600;
  }

  .action-group,
  .action-bar-right {
    display: flex;
    gap: 1rem;
  }
  .action-bar-right {
    justify-content: flex-end;
    flex-shrink: 0;
  }

  /* --- WALLET CARDS --- */
  .card {
    flex: 1;
    max-width: 450px;
    display: flex;
    flex-direction: column;
    border: 1px solid rgba(255, 255, 255, 0.1);
    background: rgba(0, 0, 0, 0.4);
    border-radius: 12px; /* USER REQUEST: ROUNDED CORNERS */
  }
  .card-header {
    padding: 0.8rem;
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    background: rgba(255, 255, 255, 0.02);
    font-size: 0.8rem;
    letter-spacing: 1px;
    color: #fff;
    font-weight: bold;
    border-top-left-radius: 12px; /* Match Card Radius */
    border-top-right-radius: 12px;
  }
  .card-body {
    padding: 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 1.2rem;
    flex: 1;
  }
  .spacer {
    flex: 1;
  }
  .desc {
    font-size: 0.75rem;
    color: #888;
    margin: 0;
  }
  .divider {
    height: 1px;
    background: rgba(255, 255, 255, 0.1);
    margin: 0.5rem 0;
  }
  .btn-row {
    display: flex;
    gap: 0.8rem;
    margin-top: auto;
  }

  /* --- BUTTONS --- */
  .cyber-btn {
    background: rgba(0, 255, 65, 0.05);
    border: 1px solid var(--color-primary);
    color: var(--color-primary);
    padding: 0.8rem 1.5rem;
    letter-spacing: 1px;
    font-weight: bold;
    transition: all 0.2s;
    cursor: pointer;
    text-transform: uppercase;
    font-size: 0.8rem;
    white-space: nowrap;
  }
  .cyber-btn:hover {
    background: var(--color-primary);
    color: #000;
    box-shadow: 0 0 15px rgba(0, 255, 65, 0.4);
  }
  .cyber-btn.ghost {
    border-color: rgba(255, 255, 255, 0.2);
    color: #aaa;
    background: transparent;
  }
  .cyber-btn.ghost:hover {
    border-color: #fff;
    color: #fff;
    box-shadow: none;
    background: rgba(255, 255, 255, 0.05);
  }
  .cyber-btn.danger:hover {
    border-color: #ff5555;
    color: #ff5555;
  }
  .cyber-btn.wide {
    width: 100%;
  }

  /* === DATA TAB STYLES === */
  .data-view {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
    padding: 0.5rem 0;
    overflow-y: auto;
  }
  .data-panel {
    background: rgba(0, 0, 0, 0.3);
    border: 1px solid rgba(0, 255, 65, 0.15);
    border-radius: 8px;
    padding: 1.2rem 1.5rem;
  }
  .data-title {
    font-size: 1rem;
    color: var(--color-primary);
    margin: 0 0 1.2rem 0;
    letter-spacing: 2px;
  }

  /* Path Row */
  .path-row {
    display: flex;
    gap: 1rem;
    align-items: center;
    padding: 0.8rem 1rem;
    background: rgba(0, 0, 0, 0.5);
    border: 1px solid rgba(0, 255, 65, 0.1);
    border-radius: 6px;
    margin-bottom: 1rem;
  }
  .path-label {
    color: #666;
    font-size: 0.75rem;
    letter-spacing: 1px;
    flex-shrink: 0;
  }
  .path-value {
    color: var(--color-primary);
    font-size: 0.85rem;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  /* Status Grid - 4 columns */
  .status-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 0.8rem;
    margin-bottom: 1.2rem;
  }
  .status-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.4rem;
    padding: 0.8rem;
    background: rgba(0, 0, 0, 0.4);
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 6px;
    text-align: center;
  }
  .status-label {
    color: #555;
    font-size: 0.65rem;
    letter-spacing: 1px;
    text-transform: uppercase;
  }
  .status-value {
    color: #888;
    font-size: 0.85rem;
    font-weight: 600;
  }
  .status-value.ok {
    color: var(--color-primary);
  }

  /* Data Actions */
  .data-actions {
    display: flex;
    gap: 1rem;
    flex-wrap: wrap;
  }

  /* Config Warning */
  .config-warning {
    display: flex;
    align-items: center;
    gap: 1rem;
    margin-top: 1rem;
    padding: 0.8rem 1rem;
    background: rgba(255, 68, 68, 0.1);
    border-color: #ff6666;
  }
  .cyber-btn.warning {
    background: rgba(255, 165, 0, 0.2);
    border-color: #ffa500;
    color: #ffa500;
  }
  .cyber-btn.warning:hover {
    background: rgba(255, 165, 0, 0.4);
    box-shadow: 0 0 15px rgba(255, 165, 0, 0.4);
  }
  .cyber-btn.info {
    background: rgba(0, 191, 255, 0.2);
    border-color: #00bfff;
    color: #00bfff;
  }
  .cyber-btn.info:hover {
    background: rgba(0, 191, 255, 0.4);
    box-shadow: 0 0 15px rgba(0, 191, 255, 0.4);
  }

  .cyber-btn.small {
    padding: 0.4rem 0.8rem;
    font-size: 0.7rem;
  }

  /* Education Section */
  .education-section {
    background: rgba(0, 0, 0, 0.3);
    border: 1px solid rgba(0, 255, 65, 0.15);
    border-radius: 8px;
    padding: 1rem 1.2rem;
  }
  .section-title {
    font-size: 0.9rem;
    color: var(--color-primary);
    margin: 0 0 1rem 0;
    letter-spacing: 1px;
  }
  .edu-content {
    color: #aaa;
    font-size: 0.85rem;
    line-height: 1.6;
  }
  .edu-content p {
    margin: 0.5rem 0;
  }
  .edu-content strong {
    color: var(--color-primary);
  }
  .edu-list {
    margin: 0.8rem 0;
    padding-left: 1.5rem;
  }
  .edu-list li {
    margin: 0.4rem 0;
  }
  .edu-list li strong {
    color: #fff;
  }
  .warning-text {
    color: #ff6666;
    font-weight: bold;
  }

  /* === UPDATE TAB STYLES === */
  .update-view {
    display: flex;
    flex-direction: column;
    gap: 1rem; /* User Request: Compact layout */
    padding: 0.5rem 0;
    overflow-y: auto;
  }
  .update-panel {
    background: rgba(0, 0, 0, 0.3);
    border: 1px solid rgba(0, 255, 65, 0.15);
    border-radius: 8px;
    padding: 0.6rem 0.8rem; /* User Request: Compact layout */
  }
  .update-title {
    font-size: 1rem;
    color: var(--color-primary);
    margin: 0 0 1.2rem 0;
    letter-spacing: 2px;
  }

  /* Version Grid - 3 columns */
  .version-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 1rem;
    margin-bottom: 1.5rem;
  }
  .version-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.4rem;
    padding: 1rem;
    background: rgba(0, 0, 0, 0.4);
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 8px;
    text-align: center;
  }
  .version-label {
    color: #555;
    font-size: 0.7rem;
    letter-spacing: 1px;
    text-transform: uppercase;
  }
  .version-value {
    color: #888;
    font-size: 1rem;
    font-weight: 600;
    font-family: var(--font-mono);
  }
  .version-value.ok {
    color: var(--color-primary);
  }

  /* === MODAL === */
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.8);
    backdrop-filter: blur(4px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 2000;
  }
  .modal-staged {
    width: 100%;
    max-width: 400px;
    background: rgba(10, 10, 10, 0.95);
    border: 1px solid var(--color-primary);
    border-radius: 12px;
    box-shadow: 0 0 40px rgba(0, 255, 65, 0.1);
    overflow: hidden;
  }
  .modal-header {
    background: rgba(0, 255, 65, 0.1);
    padding: 1rem 1.5rem;
    border-bottom: 1px solid rgba(0, 255, 65, 0.2);
  }
  .modal-header h3 {
    margin: 0;
    font-size: 1rem;
    color: var(--color-primary);
    letter-spacing: 1px;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  .modal-body {
    padding: 2rem;
    color: #ccc;
    text-align: center;
  }
  .modal-actions {
    display: flex;
    gap: 1rem;
    padding: 1.5rem;
    background: rgba(0, 0, 0, 0.3);
    justify-content: center;
  }

  /* Binary Status */
  .binary-status {
    margin-bottom: 1.5rem;
  }
  .section-subtitle {
    color: #666;
    font-size: 0.75rem;
    letter-spacing: 1px;
    margin: 0 0 0.8rem 0;
    text-transform: uppercase;
  }
  .binary-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.6rem 1rem;
    background: rgba(0, 0, 0, 0.3);
    border-radius: 4px;
    margin-bottom: 0.4rem;
  }
  .binary-name {
    color: #aaa;
    font-size: 0.85rem;
  }
  .binary-status-badge {
    font-size: 0.75rem;
    padding: 0.2rem 0.6rem;
    border-radius: 4px;
    background: rgba(255, 68, 68, 0.15);
    color: #ff6666;
  }
  .binary-status-badge.found {
    background: rgba(0, 255, 65, 0.1);
    color: var(--color-primary);
  }

  /* Update Check Section */
  .update-check-section {
    margin-bottom: 1.5rem;
  }
  .update-actions {
    display: flex;
    gap: 1rem;
    margin-bottom: 0.8rem;
  }
  .update-status {
    color: #888;
    font-size: 0.8rem;
    padding: 0.8rem;
    background: rgba(0, 0, 0, 0.3);
    border-radius: 4px;
    margin-bottom: 0.8rem;
  }
  .update-fallback {
    text-align: center;
    padding: 0.5rem;
    margin-top: 1rem; /* Separate from content above */
  }
  .update-fallback a {
    color: var(--color-primary);
    text-decoration: none;
    font-size: 0.85rem;
    transition: opacity 0.2s;
  }
  .update-fallback a:hover {
    opacity: 0.8;
    text-decoration: underline;
  }

  /* Checksum Section */
  .checksum-section {
    border-top: 1px solid rgba(255, 255, 255, 0.05);
    padding-top: 1rem;
  }
  .coming-soon {
    color: #666;
    font-size: 0.85rem;
    padding: 1rem;
    background: rgba(0, 0, 0, 0.3);
    border: 1px dashed rgba(255, 255, 255, 0.1);
    border-radius: 6px;
    text-align: center;
  }
</style>
