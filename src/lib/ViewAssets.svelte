<script>
    import { onMount } from "svelte";
    import { fly, fade, scale } from "svelte/transition";
    import { core } from "@tauri-apps/api";

    let activeTab = "MY_ASSETS";
    let myAssets = [];
    let tauriReady = false;
    let status = "";

    // Detail View
    let selectedDetail = null;

    // Transfer
    let selectedAsset = "";
    let transferTo = "";
    let transferAmt = "";

    // Issue
    let issueName = "";
    let issueQty = "1";
    let issueUnits = "0";
    let issueReissue = true;

    // Reissue
    let reissueAsset = "";
    let reissueQty = "0";
    let reissueReissuable = true;

    // Confirm Modal
    let confirmOpen = false;
    let confirmPayload = null;
    let confirmType = "";

    // Allow parent to pass initial state
    export let isNodeOnline = false;

    // Always allow operations - errors will be shown if node is offline
    let nodeOnline = true; // Default to true, let operations fail gracefully

    onMount(async () => {
        tauriReady =
            typeof core?.isTauri === "function" ? core.isTauri() : false;
        if (tauriReady) {
            // Try to refresh assets, will fail gracefully if node is offline
            await refreshAssets();
        }
    });

    // Re-check when parent state changes
    $: if (tauriReady && isNodeOnline) {
        refreshAssets();
    }

    async function refreshAssets() {
        if (!tauriReady) return;
        try {
            myAssets = await core.invoke("list_assets");
            nodeOnline = true;
            status = "";
            if (!selectedAsset && myAssets.length > 0)
                selectedAsset = myAssets[0].name;
            if (!reissueAsset && myAssets.length > 0)
                reissueAsset = myAssets[0].name;
        } catch (err) {
            // Don't set nodeOnline to false - just show status
            console.warn("list_assets error:", err);
            status = String(err).includes("error") ? "Node may be offline" : "";
            myAssets = [];
        }
    }

    function openDetail(asset) {
        selectedDetail = asset;
    }

    function closeDetail() {
        selectedDetail = null;
    }

    function goToTransfer(assetName) {
        selectedAsset = assetName;
        selectedDetail = null;
        activeTab = "TRANSFER";
    }

    function initiateTransfer() {
        if (!selectedAsset || !transferTo || !transferAmt) {
            status = "Fill all fields.";
            return;
        }
        confirmPayload = {
            asset: selectedAsset,
            to: transferTo,
            amount: transferAmt,
        };
        confirmType = "TRANSFER";
        confirmOpen = true;
    }

    function initiateIssue() {
        if (!issueName || !issueQty) {
            status = "Name and Qty required.";
            return;
        }
        confirmPayload = {
            name: issueName.toUpperCase(),
            qty: issueQty,
            units: issueUnits,
            reissuable: issueReissue,
        };
        confirmType = "ISSUE";
        confirmOpen = true;
    }

    function initiateReissue() {
        if (!reissueAsset || !reissueQty) {
            status = "Asset and Qty required.";
            return;
        }
        confirmPayload = {
            name: reissueAsset,
            qty: reissueQty,
            reissuable: reissueReissuable,
        };
        confirmType = "REISSUE";
        confirmOpen = true;
    }

    async function confirmAction() {
        if (!tauriReady) return;
        try {
            let txid = "";
            if (confirmType === "TRANSFER") {
                txid = await core.invoke("transfer_asset", {
                    asset: confirmPayload.asset,
                    amount: confirmPayload.amount,
                    to: confirmPayload.to,
                });
                status = `Sent! TXID: ${txid.slice(0, 16)}...`;
                transferTo = "";
                transferAmt = "";
            } else if (confirmType === "ISSUE") {
                txid = await core.invoke("issue_asset", {
                    name: confirmPayload.name,
                    qty: String(confirmPayload.qty),
                    units: Number(confirmPayload.units),
                    reissuable: confirmPayload.reissuable,
                });
                status = `Issued! TXID: ${txid.slice(0, 16)}...`;
                issueName = "";
                issueQty = "1";
            } else if (confirmType === "REISSUE") {
                txid = await core
                    .invoke("reissue_asset", {
                        name: confirmPayload.name,
                        qty: String(confirmPayload.qty),
                        reissuable: confirmPayload.reissuable,
                    })
                    .catch((e) => {
                        throw "Reissue not ready: " + e;
                    });
                status = `Reissued! TXID: ${txid.slice(0, 16)}...`;
            }
            confirmOpen = false;
            refreshAssets();
        } catch (err) {
            status = "Error: " + err;
            confirmOpen = false;
        }
    }
</script>

<div class="view-assets">
    <div class="cyber-panel main-frame">
        <!-- HEADER / TABS -->
        <header class="panel-header">
            <nav class="nav-tabs">
                <button
                    class="nav-tab"
                    class:active={activeTab === "MY_ASSETS"}
                    on:click={() => (activeTab = "MY_ASSETS")}
                >
                    <span class="tab-icon">◈</span> MY ASSETS
                </button>
                <button
                    class="nav-tab"
                    class:active={activeTab === "TRANSFER"}
                    on:click={() => (activeTab = "TRANSFER")}
                >
                    <span class="tab-icon">→</span> TRANSFER
                </button>
                <button
                    class="nav-tab"
                    class:active={activeTab === "ISSUE"}
                    on:click={() => (activeTab = "ISSUE")}
                >
                    <span class="tab-icon">+</span> ISSUE
                </button>
                <button
                    class="nav-tab"
                    class:active={activeTab === "REISSUE"}
                    on:click={() => (activeTab = "REISSUE")}
                >
                    <span class="tab-icon">↻</span> REISSUE
                </button>
            </nav>
            <div class="header-status">
                <span class="pulse-dot" class:online={nodeOnline}></span>
                <span class="status-label"
                    >{nodeOnline ? "CONNECTED" : "OFFLINE"}</span
                >
            </div>
        </header>

        <!-- CONTENT -->
        <div class="content-area">
            {#key activeTab}
                <div class="tab-content" in:fly={{ y: 12, duration: 250 }}>
                    <!-- ═══════════════ MY ASSETS ═══════════════ -->
                    {#if activeTab === "MY_ASSETS"}
                        <div class="asset-grid">
                            {#each myAssets as asset, i}
                                <div
                                    class="asset-card glass-card"
                                    role="button"
                                    tabindex="0"
                                    on:click={() => openDetail(asset)}
                                    on:keydown={(e) =>
                                        e.key === "Enter" && openDetail(asset)}
                                    in:fly={{
                                        y: 20,
                                        delay: i * 40,
                                        duration: 300,
                                    }}
                                >
                                    <div class="card-glow"></div>
                                    <div class="card-content">
                                        <div class="asset-name">
                                            {asset.name}
                                        </div>
                                        <div class="asset-balance">
                                            {asset.balance}
                                        </div>
                                        <div class="asset-meta">
                                            <span class="asset-type"
                                                >{asset.type}</span
                                            >
                                            <button
                                                class="quick-transfer"
                                                title="Transfer"
                                                on:click|stopPropagation={() =>
                                                    goToTransfer(asset.name)}
                                            >
                                                →
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            {/each}
                            {#if myAssets.length === 0}
                                <div class="empty-state">
                                    <div class="empty-icon">◈</div>
                                    <div class="empty-text">
                                        {nodeOnline
                                            ? "No assets in wallet"
                                            : "Connect node to view assets"}
                                    </div>
                                </div>
                            {/if}
                        </div>

                        <!-- ═══════════════ TRANSFER ═══════════════ -->
                    {:else if activeTab === "TRANSFER"}
                        <div class="form-panel glass-form">
                            <div class="form-grid">
                                <div class="form-group full">
                                    <label for="tx-asset">SELECT ASSET</label>
                                    <select
                                        id="tx-asset"
                                        bind:value={selectedAsset}
                                        class="glass-input"
                                    >
                                        {#each myAssets as item}
                                            <option value={item.name}
                                                >{item.name} • {item.balance}</option
                                            >
                                        {/each}
                                    </select>
                                </div>
                                <div class="form-group wide">
                                    <label for="tx-to">RECIPIENT ADDRESS</label>
                                    <input
                                        id="tx-to"
                                        type="text"
                                        class="glass-input mono"
                                        placeholder="Enter address..."
                                        bind:value={transferTo}
                                    />
                                </div>
                                <div class="form-group narrow">
                                    <label for="tx-amt">AMOUNT</label>
                                    <input
                                        id="tx-amt"
                                        type="number"
                                        class="glass-input mono"
                                        placeholder="0"
                                        bind:value={transferAmt}
                                    />
                                </div>
                            </div>
                            <div class="form-footer">
                                <button
                                    class="neon-btn"
                                    on:click={initiateTransfer}
                                    disabled={!nodeOnline}
                                >
                                    <span class="btn-glow"></span>
                                    SEND TRANSFER
                                </button>
                            </div>
                        </div>

                        <!-- ═══════════════ ISSUE ═══════════════ -->
                    {:else if activeTab === "ISSUE"}
                        <div class="form-panel glass-form">
                            <div class="form-grid">
                                <div class="form-group wide">
                                    <label for="issue-name">ASSET NAME</label>
                                    <input
                                        id="issue-name"
                                        type="text"
                                        class="glass-input mono"
                                        placeholder="MY_TOKEN"
                                        bind:value={issueName}
                                    />
                                </div>
                                <div class="form-group narrow">
                                    <span class="label-text">COST</span>
                                    <div class="static-value">0.25 HEMP</div>
                                </div>
                                <div class="form-group">
                                    <label for="issue-qty">QUANTITY</label>
                                    <input
                                        id="issue-qty"
                                        type="number"
                                        class="glass-input mono"
                                        placeholder="1"
                                        bind:value={issueQty}
                                    />
                                </div>
                                <div class="form-group tiny">
                                    <label for="issue-units">UNITS</label>
                                    <input
                                        id="issue-units"
                                        type="number"
                                        class="glass-input mono"
                                        min="0"
                                        max="8"
                                        bind:value={issueUnits}
                                    />
                                </div>
                                <div class="form-group checkbox-group">
                                    <label class="checkbox-wrap">
                                        <input
                                            type="checkbox"
                                            bind:checked={issueReissue}
                                        />
                                        <span class="checkbox-visual"></span>
                                        <span class="checkbox-text"
                                            >REISSUABLE</span
                                        >
                                    </label>
                                </div>
                            </div>
                            <div class="form-footer">
                                <button
                                    class="neon-btn"
                                    on:click={initiateIssue}
                                    disabled={!nodeOnline}
                                >
                                    <span class="btn-glow"></span>
                                    MINT ASSET
                                </button>
                            </div>
                        </div>

                        <!-- ═══════════════ REISSUE ═══════════════ -->
                    {:else if activeTab === "REISSUE"}
                        <div class="form-panel glass-form">
                            <div class="form-grid">
                                <div class="form-group wide">
                                    <label for="reissue-asset"
                                        >SELECT ASSET</label
                                    >
                                    <select
                                        id="reissue-asset"
                                        bind:value={reissueAsset}
                                        class="glass-input"
                                    >
                                        {#each myAssets as item}
                                            <option value={item.name}
                                                >{item.name}</option
                                            >
                                        {/each}
                                    </select>
                                </div>
                                <div class="form-group narrow">
                                    <span class="label-text">COST</span>
                                    <div class="static-value">0.25 HEMP</div>
                                </div>
                                <div class="form-group">
                                    <label for="reissue-qty">ADD QUANTITY</label
                                    >
                                    <input
                                        id="reissue-qty"
                                        type="number"
                                        class="glass-input mono"
                                        placeholder="0"
                                        bind:value={reissueQty}
                                    />
                                </div>
                                <div class="form-group checkbox-group">
                                    <label class="checkbox-wrap">
                                        <input
                                            type="checkbox"
                                            bind:checked={reissueReissuable}
                                        />
                                        <span class="checkbox-visual"></span>
                                        <span class="checkbox-text"
                                            >KEEP REISSUABLE</span
                                        >
                                    </label>
                                </div>
                            </div>
                            <div class="form-footer">
                                <button
                                    class="neon-btn"
                                    on:click={initiateReissue}
                                    disabled={!nodeOnline}
                                >
                                    <span class="btn-glow"></span>
                                    REISSUE ASSET
                                </button>
                            </div>
                        </div>
                    {/if}
                </div>
            {/key}
        </div>

        <!-- STATUS BAR -->
        {#if status}
            <div
                class="status-bar"
                class:error={status.startsWith("Error")}
                transition:fly={{ y: 10 }}
            >
                <span class="status-indicator">▶</span>
                {status}
            </div>
        {/if}
    </div>

    <!-- ═══════════════ ASSET DETAIL MODAL ═══════════════ -->
    {#if selectedDetail}
        <div
            class="modal-overlay"
            transition:fade={{ duration: 150 }}
            on:click={closeDetail}
            on:keydown={(e) => e.key === "Escape" && closeDetail()}
            role="button"
            tabindex="0"
        >
            <div
                class="detail-modal glass-modal"
                transition:scale={{ start: 0.95, duration: 200 }}
                on:click|stopPropagation
                on:keydown|stopPropagation
                role="dialog"
                aria-modal="true"
                tabindex="-1"
            >
                <button class="modal-close" on:click={closeDetail}>×</button>

                <div class="detail-header">
                    <div class="detail-icon">◈</div>
                    <div class="detail-title">{selectedDetail.name}</div>
                </div>

                <div class="detail-body">
                    <div class="detail-grid">
                        <div class="detail-stat">
                            <div class="stat-label">BALANCE</div>
                            <div class="stat-value neon-text">
                                {selectedDetail.balance}
                            </div>
                        </div>
                        <div class="detail-stat">
                            <div class="stat-label">TYPE</div>
                            <div class="stat-value">
                                {selectedDetail.type || "STANDARD"}
                            </div>
                        </div>
                        <div class="detail-stat">
                            <div class="stat-label">REISSUABLE</div>
                            <div class="stat-value">
                                {selectedDetail.reissuable ? "YES" : "NO"}
                            </div>
                        </div>
                        <div class="detail-stat">
                            <div class="stat-label">UNITS</div>
                            <div class="stat-value">
                                {selectedDetail.units ?? 0}
                            </div>
                        </div>
                    </div>

                    <div class="detail-actions">
                        <button
                            class="action-btn primary"
                            on:click={() => goToTransfer(selectedDetail.name)}
                        >
                            <span class="action-icon">→</span> TRANSFER
                        </button>
                        <button
                            class="action-btn"
                            on:click={() => {
                                reissueAsset = selectedDetail.name;
                                selectedDetail = null;
                                activeTab = "REISSUE";
                            }}
                        >
                            <span class="action-icon">↻</span> REISSUE
                        </button>
                    </div>
                </div>
            </div>
        </div>
    {/if}

    <!-- ═══════════════ CONFIRM MODAL ═══════════════ -->
    {#if confirmOpen}
        <div class="modal-overlay" transition:fade={{ duration: 100 }}>
            <div class="confirm-modal glass-modal" transition:fly={{ y: 15 }}>
                <div class="confirm-header">CONFIRM {confirmType}</div>
                <div class="confirm-body">
                    {#each Object.entries(confirmPayload) as [k, v]}
                        <div class="confirm-row">
                            <span class="row-key">{k}</span>
                            <span class="row-val">{v}</span>
                        </div>
                    {/each}
                </div>
                <div class="confirm-footer">
                    <button
                        class="ghost-btn"
                        on:click={() => (confirmOpen = false)}>CANCEL</button
                    >
                    <button class="neon-btn sm" on:click={confirmAction}
                        >CONFIRM</button
                    >
                </div>
            </div>
        </div>
    {/if}
</div>

<style>
    /* ═══════════════ BASE LAYOUT ═══════════════ */
    .view-assets {
        height: 100%;
        display: flex;
        flex-direction: column;
    }
    .main-frame {
        flex: 1;
        display: flex;
        flex-direction: column;
        background: linear-gradient(
            180deg,
            rgba(8, 14, 12, 0.95) 0%,
            rgba(5, 10, 8, 0.98) 100%
        );
        border: 1px solid rgba(0, 255, 65, 0.15);
        border-radius: 16px;
        overflow: hidden;
        box-shadow:
            0 0 60px rgba(0, 0, 0, 0.5),
            inset 0 0 80px rgba(0, 255, 65, 0.02);
    }

    /* ═══════════════ HEADER / NAV ═══════════════ */
    .panel-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 0 1rem;
        background: rgba(0, 0, 0, 0.4);
        border-bottom: 1px solid rgba(0, 255, 65, 0.1);
        flex-shrink: 0;
    }
    .nav-tabs {
        display: flex;
        gap: 0;
    }
    .nav-tab {
        background: transparent;
        border: none;
        color: #555;
        padding: 0.8rem 1.2rem;
        font-size: 0.7rem;
        font-weight: 600;
        letter-spacing: 1.5px;
        border-bottom: 2px solid transparent;
        cursor: pointer;
        transition: all 0.2s;
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }
    .nav-tab:hover {
        color: #aaa;
        background: rgba(255, 255, 255, 0.02);
    }
    .nav-tab.active {
        color: var(--color-primary);
        border-bottom-color: var(--color-primary);
        text-shadow: 0 0 10px rgba(0, 255, 65, 0.5);
    }
    .tab-icon {
        font-size: 0.9rem;
    }
    .header-status {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        font-size: 0.65rem;
        color: #555;
        letter-spacing: 1px;
    }
    .pulse-dot {
        width: 6px;
        height: 6px;
        border-radius: 50%;
        background: #333;
        animation: pulse 2s infinite;
    }
    .pulse-dot.online {
        background: var(--color-primary);
        box-shadow: 0 0 8px var(--color-primary);
    }
    @keyframes pulse {
        0%,
        100% {
            opacity: 1;
        }
        50% {
            opacity: 0.5;
        }
    }

    /* ═══════════════ CONTENT AREA ═══════════════ */
    .content-area {
        flex: 1;
        overflow: hidden;
        display: flex;
    }
    .tab-content {
        flex: 1;
        padding: 1.5rem;
        overflow-y: auto;
    }

    /* ═══════════════ ASSET GRID (Card Layout) ═══════════════ */
    .asset-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
        gap: 1rem;
    }
    .asset-card {
        position: relative;
        background: rgba(0, 0, 0, 0.3);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 12px;
        padding: 1.2rem;
        cursor: pointer;
        transition: all 0.25s;
        overflow: hidden;
    }
    .asset-card:hover {
        border-color: rgba(0, 255, 65, 0.4);
        transform: translateY(-2px);
        box-shadow:
            0 8px 30px rgba(0, 0, 0, 0.4),
            0 0 20px rgba(0, 255, 65, 0.1);
    }
    .asset-card:hover .card-glow {
        opacity: 1;
    }
    .card-glow {
        position: absolute;
        inset: 0;
        background: radial-gradient(
            circle at 50% 120%,
            rgba(0, 255, 65, 0.08) 0%,
            transparent 60%
        );
        opacity: 0;
        transition: opacity 0.3s;
        pointer-events: none;
    }
    .card-content {
        position: relative;
        z-index: 1;
    }
    .asset-name {
        font-size: 0.9rem;
        font-weight: 700;
        color: #fff;
        letter-spacing: 1px;
        margin-bottom: 0.5rem;
        text-overflow: ellipsis;
        overflow: hidden;
        white-space: nowrap;
    }
    .asset-balance {
        font-size: 1.4rem;
        font-weight: 700;
        color: var(--color-primary);
        font-family: var(--font-mono);
        text-shadow: 0 0 15px rgba(0, 255, 65, 0.4);
        margin-bottom: 0.8rem;
    }
    .asset-meta {
        display: flex;
        justify-content: space-between;
        align-items: center;
    }
    .asset-type {
        font-size: 0.55rem;
        padding: 3px 8px;
        border: 1px solid rgba(255, 255, 255, 0.15);
        border-radius: 6px;
        color: #777;
        letter-spacing: 1px;
        background: rgba(0, 0, 0, 0.3);
    }
    .quick-transfer {
        width: 28px;
        height: 28px;
        background: rgba(0, 255, 65, 0.1);
        border: 1px solid rgba(0, 255, 65, 0.3);
        border-radius: 8px;
        color: var(--color-primary);
        font-size: 1rem;
        cursor: pointer;
        transition: all 0.15s;
        display: flex;
        align-items: center;
        justify-content: center;
    }
    .quick-transfer:hover {
        background: var(--color-primary);
        color: #000;
        box-shadow: 0 0 15px var(--color-primary);
    }

    .empty-state {
        grid-column: 1 / -1;
        text-align: center;
        padding: 4rem 2rem;
        color: #444;
    }
    .empty-icon {
        font-size: 3rem;
        margin-bottom: 1rem;
        opacity: 0.3;
    }
    .empty-text {
        font-size: 0.85rem;
        letter-spacing: 1px;
    }

    /* ═══════════════ FORMS ═══════════════ */
    .form-panel {
        max-width: 700px;
        margin: 0 auto;
        padding: 2rem;
        background: rgba(0, 0, 0, 0.2);
        border: 1px solid rgba(255, 255, 255, 0.05);
        border-radius: 16px;
    }
    .form-grid {
        display: grid;
        grid-template-columns: repeat(12, 1fr);
        gap: 1rem 1.5rem;
    }
    .form-group {
        display: flex;
        flex-direction: column;
        gap: 0.4rem;
    }
    .form-group.full {
        grid-column: span 12;
    }
    .form-group.wide {
        grid-column: span 8;
    }
    .form-group.narrow {
        grid-column: span 4;
    }
    .form-group.tiny {
        grid-column: span 2;
    }
    .form-group:not(.full):not(.wide):not(.narrow):not(.tiny) {
        grid-column: span 6;
    }
    .form-group.checkbox-group {
        grid-column: span 4;
        justify-content: center;
    }

    label,
    .label-text {
        font-size: 0.6rem;
        color: #666;
        letter-spacing: 1.5px;
        text-transform: uppercase;
    }

    .glass-input {
        background: rgba(0, 0, 0, 0.5);
        border: 1px solid rgba(255, 255, 255, 0.1);
        color: #fff;
        padding: 0.7rem 1rem;
        font-size: 0.85rem;
        border-radius: 10px;
        outline: none;
        width: 100%;
        transition: all 0.2s;
        backdrop-filter: blur(5px);
    }
    .glass-input:focus {
        border-color: var(--color-primary);
        box-shadow:
            0 0 20px rgba(0, 255, 65, 0.15),
            inset 0 0 20px rgba(0, 255, 65, 0.03);
    }
    .glass-input::placeholder {
        color: #444;
    }
    select.glass-input {
        cursor: pointer;
        appearance: none;
        background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='%2300ff41'%3E%3Cpath d='M7 10l5 5 5-5z'/%3E%3C/svg%3E");
        background-repeat: no-repeat;
        background-position: right 10px center;
        background-size: 14px;
        padding-right: 32px;
    }
    select.glass-input option {
        background: #0a0a0a;
        color: #ccc;
    }

    .static-value {
        padding: 0.7rem 1rem;
        background: rgba(255, 255, 255, 0.03);
        border: 1px solid transparent;
        border-radius: 10px;
        color: #888;
        font-size: 0.85rem;
        font-family: var(--font-mono);
    }

    /* Checkbox */
    .checkbox-wrap {
        display: flex;
        align-items: center;
        gap: 0.6rem;
        cursor: pointer;
        padding: 0.5rem 0;
    }
    .checkbox-wrap input {
        display: none;
    }
    .checkbox-visual {
        width: 16px;
        height: 16px;
        border: 2px solid #444;
        border-radius: 4px;
        transition: all 0.15s;
        position: relative;
    }
    .checkbox-wrap input:checked + .checkbox-visual {
        background: var(--color-primary);
        border-color: var(--color-primary);
        box-shadow: 0 0 10px var(--color-primary);
    }
    .checkbox-wrap input:checked + .checkbox-visual::after {
        content: "✓";
        position: absolute;
        top: -1px;
        left: 2px;
        font-size: 11px;
        color: #000;
        font-weight: bold;
    }
    .checkbox-text {
        font-size: 0.65rem;
        color: #888;
        letter-spacing: 1px;
    }
    .checkbox-wrap input:checked ~ .checkbox-text {
        color: #fff;
    }

    .form-footer {
        margin-top: 1.5rem;
        display: flex;
        justify-content: flex-end;
    }

    /* ═══════════════ BUTTONS ═══════════════ */
    .neon-btn {
        position: relative;
        background: linear-gradient(
            180deg,
            rgba(0, 255, 65, 0.15) 0%,
            rgba(0, 255, 65, 0.05) 100%
        );
        border: 1px solid var(--color-primary);
        color: var(--color-primary);
        padding: 0.8rem 2rem;
        font-size: 0.75rem;
        font-weight: 700;
        letter-spacing: 2px;
        border-radius: 10px;
        cursor: pointer;
        transition: all 0.2s;
        overflow: hidden;
    }
    .neon-btn:hover:not(:disabled) {
        background: var(--color-primary);
        color: #000;
        box-shadow:
            0 0 30px var(--color-primary),
            0 0 60px rgba(0, 255, 65, 0.3);
        transform: translateY(-1px);
    }
    .neon-btn:disabled {
        opacity: 0.4;
        cursor: not-allowed;
    }
    .neon-btn.sm {
        padding: 0.6rem 1.5rem;
    }
    .btn-glow {
        position: absolute;
        inset: -50%;
        background: conic-gradient(
            transparent,
            transparent,
            transparent,
            rgba(0, 255, 65, 0.2)
        );
        animation: spin 4s linear infinite;
        opacity: 0;
    }
    .neon-btn:hover .btn-glow {
        opacity: 1;
    }
    @keyframes spin {
        100% {
            transform: rotate(360deg);
        }
    }

    .ghost-btn {
        background: transparent;
        border: 1px solid #444;
        color: #888;
        padding: 0.6rem 1.5rem;
        font-size: 0.7rem;
        letter-spacing: 1px;
        border-radius: 8px;
        cursor: pointer;
        transition: all 0.15s;
    }
    .ghost-btn:hover {
        border-color: #888;
        color: #fff;
    }

    /* ═══════════════ STATUS BAR ═══════════════ */
    .status-bar {
        padding: 0.4rem 1rem;
        font-size: 0.65rem;
        color: #666;
        background: rgba(0, 0, 0, 0.5);
        border-top: 1px solid rgba(255, 255, 255, 0.03);
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }
    .status-bar.error {
        color: #ff5555;
    }
    .status-indicator {
        color: var(--color-primary);
    }

    /* ═══════════════ MODALS ═══════════════ */
    .modal-overlay {
        position: fixed;
        inset: 0;
        background: rgba(0, 0, 0, 0.85);
        backdrop-filter: blur(8px);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 1000;
        padding: 2rem;
    }
    .glass-modal {
        background: rgba(10, 15, 12, 0.95);
        border: 1px solid rgba(0, 255, 65, 0.25);
        border-radius: 16px;
        box-shadow:
            0 0 80px rgba(0, 0, 0, 0.8),
            0 0 40px rgba(0, 255, 65, 0.1);
        overflow: hidden;
    }

    /* Detail Modal */
    .detail-modal {
        width: 100%;
        max-width: 450px;
        position: relative;
    }
    .modal-close {
        position: absolute;
        top: 1rem;
        right: 1rem;
        background: transparent;
        border: none;
        color: #555;
        font-size: 1.5rem;
        cursor: pointer;
        transition: all 0.15s;
        width: 32px;
        height: 32px;
        display: flex;
        align-items: center;
        justify-content: center;
        border-radius: 8px;
    }
    .modal-close:hover {
        color: #fff;
        background: rgba(255, 255, 255, 0.1);
    }
    .detail-header {
        padding: 2rem 2rem 1.5rem;
        text-align: center;
        border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    }
    .detail-icon {
        font-size: 2.5rem;
        color: var(--color-primary);
        text-shadow: 0 0 30px rgba(0, 255, 65, 0.5);
        margin-bottom: 0.5rem;
    }
    .detail-title {
        font-size: 1.3rem;
        font-weight: 700;
        color: #fff;
        letter-spacing: 2px;
    }
    .detail-body {
        padding: 1.5rem 2rem 2rem;
    }
    .detail-grid {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 1rem;
        margin-bottom: 2rem;
    }
    .detail-stat {
        background: rgba(0, 0, 0, 0.3);
        border: 1px solid rgba(255, 255, 255, 0.05);
        border-radius: 10px;
        padding: 1rem;
        text-align: center;
    }
    .stat-label {
        font-size: 0.6rem;
        color: #555;
        letter-spacing: 1px;
        margin-bottom: 0.3rem;
    }
    .stat-value {
        font-size: 1rem;
        font-weight: 600;
        color: #fff;
        font-family: var(--font-mono);
    }
    .stat-value.neon-text {
        color: var(--color-primary);
        text-shadow: 0 0 10px rgba(0, 255, 65, 0.5);
    }

    .detail-actions {
        display: flex;
        gap: 1rem;
    }
    .action-btn {
        flex: 1;
        background: rgba(255, 255, 255, 0.03);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 10px;
        padding: 0.8rem;
        color: #aaa;
        font-size: 0.7rem;
        font-weight: 600;
        letter-spacing: 1px;
        cursor: pointer;
        transition: all 0.15s;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 0.5rem;
    }
    .action-btn:hover {
        border-color: var(--color-primary);
        color: var(--color-primary);
    }
    .action-btn.primary {
        background: rgba(0, 255, 65, 0.1);
        border-color: var(--color-primary);
        color: var(--color-primary);
    }
    .action-btn.primary:hover {
        background: var(--color-primary);
        color: #000;
        box-shadow: 0 0 20px var(--color-primary);
    }
    .action-icon {
        font-size: 1rem;
    }

    /* Confirm Modal */
    .confirm-modal {
        width: 100%;
        max-width: 360px;
    }
    .confirm-header {
        padding: 1rem 1.5rem;
        font-size: 0.85rem;
        font-weight: 700;
        color: var(--color-primary);
        letter-spacing: 1px;
        border-bottom: 1px solid rgba(0, 255, 65, 0.2);
        background: rgba(0, 255, 65, 0.05);
    }
    .confirm-body {
        padding: 1.5rem;
    }
    .confirm-row {
        display: flex;
        justify-content: space-between;
        padding: 0.6rem 0;
        border-bottom: 1px solid rgba(255, 255, 255, 0.03);
        font-size: 0.8rem;
    }
    .confirm-row:last-child {
        border-bottom: none;
    }
    .row-key {
        color: #666;
        font-family: var(--font-mono);
    }
    .row-val {
        color: #fff;
        font-weight: 600;
    }
    .confirm-footer {
        display: flex;
        gap: 1rem;
        padding: 1.5rem;
        background: rgba(0, 0, 0, 0.3);
    }
    .confirm-footer button {
        flex: 1;
    }

    /* ═══════════════ SCROLLBAR ═══════════════ */
    .tab-content::-webkit-scrollbar {
        width: 6px;
    }
    .tab-content::-webkit-scrollbar-track {
        background: transparent;
    }
    .tab-content::-webkit-scrollbar-thumb {
        background: rgba(255, 255, 255, 0.1);
        border-radius: 3px;
    }
    .tab-content::-webkit-scrollbar-thumb:hover {
        background: var(--color-primary);
    }
</style>
