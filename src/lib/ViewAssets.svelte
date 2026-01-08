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
    let issueType = "root"; // "root" | "sub"
    let issueParent = ""; // Parent asset name for sub-assets
    let issueIpfs = ""; // Optional IPFS hash

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

    // Group assets: bundle OWNER tokens (!) with their parent TOKEN
    $: groupedAssets = (() => {
        const groups = new Map();
        const owners = new Map();

        // First pass: separate owners from tokens
        for (const asset of myAssets) {
            if (asset.name.endsWith("!")) {
                // This is an owner token
                const baseName = asset.name.slice(0, -1);
                owners.set(baseName, asset);
            } else {
                // Regular token or sub-asset
                groups.set(asset.name, {
                    ...asset,
                    hasOwner: false,
                    ownerBalance: null,
                    isSubAsset: asset.name.includes("/"),
                    parentName: asset.name.includes("/")
                        ? asset.name.split("/")[0]
                        : null,
                });
            }
        }

        // Second pass: attach owners to their parent tokens
        for (const [baseName, ownerAsset] of owners) {
            if (groups.has(baseName)) {
                // Parent exists, attach owner info
                const parent = groups.get(baseName);
                parent.hasOwner = true;
                parent.ownerBalance = ownerAsset.balance;
            } else {
                // Orphan owner (no matching token visible) - show it separately
                groups.set(ownerAsset.name, {
                    ...ownerAsset,
                    hasOwner: true,
                    ownerBalance: ownerAsset.balance,
                    isSubAsset: false,
                    parentName: null,
                });
            }
        }

        return Array.from(groups.values());
    })();

    // Root assets only (for sub-asset parent selection)
    $: rootAssets = myAssets.filter(
        (a) =>
            !a.name.includes("/") &&
            !a.name.endsWith("!") &&
            a.name === a.name.toUpperCase(), // Only uppercase root assets
    );

    // Asset metadata from getassetdata
    let assetMetadata = null;
    let metadataLoading = false;
    let slideDirection = 0; // -1 = left, 1 = right, 0 = none

    async function openDetail(asset) {
        selectedDetail = asset;
        assetMetadata = null;
        metadataLoading = true;

        try {
            // Fetch full asset data from CLI
            const data = await core.invoke("get_asset_data", {
                name: asset.name,
            });
            assetMetadata = data;
        } catch (err) {
            console.warn("get_asset_data error:", err);
            // Non-fatal - just show basic info
        }
        metadataLoading = false;
    }

    function closeDetail() {
        selectedDetail = null;
        assetMetadata = null;
        slideDirection = 0;
    }

    function navigatePrev() {
        if (!selectedDetail || groupedAssets.length <= 1) return;
        const currentIdx = groupedAssets.findIndex(
            (a) => a.name === selectedDetail.name,
        );
        const prevIdx =
            currentIdx <= 0 ? groupedAssets.length - 1 : currentIdx - 1;
        slideDirection = -1;
        openDetail(groupedAssets[prevIdx]);
    }

    function navigateNext() {
        if (!selectedDetail || groupedAssets.length <= 1) return;
        const currentIdx = groupedAssets.findIndex(
            (a) => a.name === selectedDetail.name,
        );
        const nextIdx =
            currentIdx >= groupedAssets.length - 1 ? 0 : currentIdx + 1;
        slideDirection = 1;
        openDetail(groupedAssets[nextIdx]);
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
        if (issueType === "sub" && !issueParent) {
            status = "Parent asset required for sub-asset.";
            return;
        }

        // Build full asset name
        let fullName = issueName.toUpperCase();
        if (issueType === "sub") {
            fullName = `${issueParent}/${issueName.toUpperCase()}`;
        }

        confirmPayload = {
            name: fullName,
            qty: issueQty,
            units: issueUnits,
            reissuable: issueReissue,
            ipfs: issueIpfs || null,
            type: issueType,
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
                    ipfs: confirmPayload.ipfs || "",
                });
                status = `${confirmPayload.type === "sub" ? "Sub-asset" : "Asset"} created! TXID: ${txid.slice(0, 16)}...`;
                issueName = "";
                issueQty = "1";
                issueIpfs = "";
                if (issueType === "sub") issueParent = "";
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
                            {#each groupedAssets as asset, i}
                                <div
                                    class="asset-card glass-card"
                                    class:has-owner={asset.hasOwner}
                                    class:is-sub-asset={asset.isSubAsset}
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
                                    {#if asset.hasOwner}
                                        <div
                                            class="owner-badge"
                                            title="You own this asset (can reissue)"
                                        >
                                            👑
                                        </div>
                                    {/if}
                                    {#if asset.isSubAsset}
                                        <div
                                            class="sub-badge"
                                            title="Sub-asset of {asset.parentName}"
                                        >
                                            ↳
                                        </div>
                                    {/if}
                                    <div class="card-content">
                                        <div class="asset-name">
                                            {asset.name}
                                        </div>
                                        <div class="asset-balance">
                                            {asset.balance}
                                        </div>
                                        <div class="asset-meta">
                                            <span class="asset-type"
                                                >{asset.hasOwner
                                                    ? "OWNER"
                                                    : asset.type}</span
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
                            {#if groupedAssets.length === 0}
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
                                <!-- Asset Type Toggle -->
                                <div class="form-group full-width">
                                    <span class="label-text">ASSET TYPE</span>
                                    <div class="toggle-group">
                                        <button
                                            class="toggle-btn"
                                            class:active={issueType === "root"}
                                            on:click={() =>
                                                (issueType = "root")}
                                            >ROOT ASSET</button
                                        >
                                        <button
                                            class="toggle-btn"
                                            class:active={issueType === "sub"}
                                            on:click={() => (issueType = "sub")}
                                            >SUB-ASSET</button
                                        >
                                    </div>
                                </div>

                                <!-- Parent Asset (only for sub-assets) -->
                                {#if issueType === "sub"}
                                    <div class="form-group wide">
                                        <label for="issue-parent"
                                            >PARENT ASSET</label
                                        >
                                        <select
                                            id="issue-parent"
                                            bind:value={issueParent}
                                            class="glass-input"
                                        >
                                            <option value=""
                                                >Select parent...</option
                                            >
                                            {#each rootAssets as asset}
                                                <option value={asset.name}
                                                    >{asset.name}</option
                                                >
                                            {/each}
                                        </select>
                                    </div>
                                {/if}

                                <div
                                    class="form-group"
                                    class:wide={issueType === "root"}
                                >
                                    <label for="issue-name">
                                        {issueType === "sub"
                                            ? "SUB-ASSET NAME"
                                            : "ASSET NAME"}
                                    </label>
                                    <input
                                        id="issue-name"
                                        type="text"
                                        class="glass-input mono"
                                        placeholder={issueType === "sub"
                                            ? "CHILD"
                                            : "MY_TOKEN"}
                                        bind:value={issueName}
                                    />
                                    {#if issueType === "sub" && issueParent}
                                        <div class="input-hint">
                                            Will create: {issueParent}/{issueName ||
                                                "..."}
                                        </div>
                                    {/if}
                                </div>

                                <div class="form-group narrow">
                                    <span class="label-text">COST</span>
                                    <div class="static-value">
                                        {issueType === "sub"
                                            ? "100 HEMP"
                                            : "500 HEMP"}
                                    </div>
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
                                    <label for="issue-units">DECIMALS</label>
                                    <input
                                        id="issue-units"
                                        type="number"
                                        class="glass-input mono"
                                        min="0"
                                        max="8"
                                        bind:value={issueUnits}
                                    />
                                </div>

                                <!-- IPFS Hash (optional) -->
                                <div class="form-group wide">
                                    <label for="issue-ipfs"
                                        >IPFS HASH (Optional)</label
                                    >
                                    <input
                                        id="issue-ipfs"
                                        type="text"
                                        class="glass-input mono"
                                        placeholder="QmYwAPJ..."
                                        bind:value={issueIpfs}
                                    />
                                    <div class="input-hint">
                                        Attach metadata document or image via
                                        IPFS
                                    </div>
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
                                    disabled={!nodeOnline ||
                                        (issueType === "sub" && !issueParent)}
                                >
                                    <span class="btn-glow"></span>
                                    {issueType === "sub"
                                        ? "CREATE SUB-ASSET"
                                        : "MINT ASSET"}
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
            <div class="modal-container">
                <!-- Navigation Arrows (outside card) -->
                {#if groupedAssets.length > 1}
                    <button
                        class="nav-arrow nav-prev"
                        on:click|stopPropagation={navigatePrev}
                        title="Previous Asset">«</button
                    >
                {/if}

                {#key selectedDetail?.name}
                    <div
                        class="detail-modal glass-modal"
                        in:fly={{ x: slideDirection * 40, duration: 180 }}
                        out:fly={{
                            x: slideDirection * -40,
                            duration: 120,
                            opacity: 0,
                        }}
                        on:click|stopPropagation
                        on:keydown|stopPropagation
                        role="dialog"
                        aria-modal="true"
                        tabindex="-1"
                    >
                        <button class="modal-close" on:click={closeDetail}
                            >×</button
                        >

                        <div class="detail-header">
                            <div class="detail-icon">◈</div>
                            <div class="detail-title">
                                {selectedDetail.name}
                            </div>
                        </div>

                        <div class="detail-body">
                            <div class="detail-grid">
                                <div class="detail-stat">
                                    <div class="stat-label">YOUR BALANCE</div>
                                    <div class="stat-value neon-text">
                                        {selectedDetail.balance}
                                    </div>
                                </div>
                                <div class="detail-stat">
                                    <div class="stat-label">TYPE</div>
                                    <div class="stat-value">
                                        {selectedDetail.isSubAsset
                                            ? "SUB-ASSET"
                                            : selectedDetail.type || "STANDARD"}
                                    </div>
                                </div>
                                <div class="detail-stat">
                                    <div class="stat-label">ADMIN RIGHTS</div>
                                    <div
                                        class="stat-value"
                                        class:owner-yes={selectedDetail.hasOwner}
                                    >
                                        {selectedDetail.hasOwner
                                            ? "👑 CAN REISSUE"
                                            : "HOLDER ONLY"}
                                    </div>
                                </div>
                                <div class="detail-stat">
                                    <div class="stat-label">DECIMALS</div>
                                    <div class="stat-value">
                                        {assetMetadata?.units ??
                                            selectedDetail.units ??
                                            0}
                                    </div>
                                </div>
                            </div>

                            <!-- Enhanced Metadata Section -->
                            {#if metadataLoading}
                                <div class="metadata-section">
                                    <div class="meta-loading">
                                        Loading metadata...
                                    </div>
                                </div>
                            {:else if assetMetadata}
                                <div class="metadata-section">
                                    <div class="meta-row">
                                        <span class="meta-label"
                                            >TOTAL SUPPLY</span
                                        >
                                        <span class="meta-value"
                                            >{assetMetadata.amount.toLocaleString()}</span
                                        >
                                    </div>
                                    <div class="meta-row">
                                        <span class="meta-label"
                                            >REISSUABLE</span
                                        >
                                        <span
                                            class="meta-value"
                                            class:yes={assetMetadata.reissuable}
                                        >
                                            {assetMetadata.reissuable
                                                ? "YES"
                                                : "NO"}
                                        </span>
                                    </div>
                                    {#if assetMetadata.has_ipfs && assetMetadata.ipfs_hash}
                                        <div class="meta-row">
                                            <span class="meta-label">IPFS</span>
                                            <span
                                                class="meta-value mono ipfs-hash"
                                                >{assetMetadata.ipfs_hash}</span
                                            >
                                        </div>
                                    {/if}
                                    <div class="meta-row">
                                        <span class="meta-label"
                                            >CREATED AT BLOCK</span
                                        >
                                        <span class="meta-value"
                                            >{assetMetadata.block_height.toLocaleString()}</span
                                        >
                                    </div>
                                </div>
                            {/if}

                            <div class="detail-actions">
                                <button
                                    class="action-btn primary"
                                    on:click={() =>
                                        goToTransfer(selectedDetail.name)}
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
                {/key}

                <!-- Right Arrow (outside card) -->
                {#if groupedAssets.length > 1}
                    <button
                        class="nav-arrow nav-next"
                        on:click|stopPropagation={navigateNext}
                        title="Next Asset">»</button
                    >
                {/if}
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

    /* Owner Badge - Crown icon for owned assets */
    .owner-badge {
        position: absolute;
        top: 8px;
        right: 8px;
        font-size: 1rem;
        z-index: 2;
        filter: drop-shadow(0 0 4px rgba(255, 215, 0, 0.6));
    }

    /* Sub-asset indicator */
    .sub-badge {
        position: absolute;
        top: 8px;
        left: 8px;
        font-size: 0.8rem;
        color: #888;
        z-index: 2;
    }

    /* Highlight cards with owner tokens */
    .asset-card.has-owner {
        border-color: rgba(255, 215, 0, 0.3);
    }
    .asset-card.has-owner:hover {
        border-color: rgba(255, 215, 0, 0.5);
        box-shadow:
            0 8px 30px rgba(0, 0, 0, 0.4),
            0 0 20px rgba(255, 215, 0, 0.15);
    }

    /* Sub-asset indent styling */
    .asset-card.is-sub-asset {
        border-left: 3px solid rgba(0, 255, 65, 0.3);
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

    .metadata-section {
        margin-top: 0.5rem;
        padding: 0.5rem 0.75rem;
        background: rgba(0, 0, 0, 0.3);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 8px;
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 0.25rem 0.75rem;
    }
    .meta-loading {
        color: #555;
        font-size: 0.7rem;
        text-align: center;
        letter-spacing: 1px;
        grid-column: 1 / -1;
    }
    .meta-row {
        display: flex;
        flex-direction: column;
        align-items: center;
        padding: 0.25rem 0;
    }
    .meta-row:last-child {
        border-bottom: none;
    }
    .meta-label {
        font-size: 0.45rem;
        color: #555;
        letter-spacing: 0.5px;
        margin-bottom: 0.1rem;
    }
    .meta-value {
        font-size: 0.7rem;
        color: #aaa;
    }
    .meta-value.yes {
        color: var(--color-primary);
    }
    .meta-value.mono {
        font-family: var(--font-mono);
    }
    .ipfs-hash {
        font-size: 0.55rem;
        max-width: 120px;
        overflow: hidden;
        text-overflow: ellipsis;
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
    .form-group.full-width {
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
    .form-group:not(.full):not(.full-width):not(.wide):not(.narrow):not(.tiny) {
        grid-column: span 6;
    }
    .form-group.checkbox-group {
        grid-column: span 4;
        justify-content: center;
    }

    /* Toggle Buttons */
    .toggle-group {
        display: flex;
        gap: 0;
        border: 1px solid rgba(0, 255, 65, 0.2);
        border-radius: 10px;
        overflow: hidden;
    }
    .toggle-btn {
        flex: 1;
        background: transparent;
        border: none;
        color: #555;
        padding: 0.7rem 1rem;
        font-size: 0.7rem;
        font-weight: 600;
        letter-spacing: 1px;
        cursor: pointer;
        transition: all 0.2s;
    }
    .toggle-btn:hover:not(.active) {
        color: #888;
        background: rgba(255, 255, 255, 0.03);
    }
    .toggle-btn.active {
        background: var(--color-primary);
        color: #000;
    }

    /* Input Hints */
    .input-hint {
        font-size: 0.6rem;
        color: #555;
        letter-spacing: 0.5px;
        margin-top: 0.2rem;
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

    /* Owner status highlight in detail modal */
    .owner-yes {
        color: #ffd700 !important;
        text-shadow: 0 0 8px rgba(255, 215, 0, 0.5);
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

    /* Modal Container (holds card + arrows) */
    .modal-container {
        display: flex;
        align-items: center;
        gap: 1rem;
    }

    /* Navigation Arrows (outside card) */
    .nav-arrow {
        flex-shrink: 0;
        background: transparent;
        border: none;
        color: var(--color-primary);
        font-size: 1.8rem;
        font-weight: 300;
        cursor: pointer;
        transition: all 0.2s;
        padding: 0.5rem;
        opacity: 0.5;
        text-shadow: 0 0 5px rgba(0, 255, 65, 0.3);
    }
    .nav-arrow:hover {
        opacity: 1;
        text-shadow:
            0 0 10px var(--color-primary),
            0 0 20px var(--color-primary),
            0 0 30px rgba(0, 255, 65, 0.5);
        transform: scale(1.2);
    }

    /* Detail Modal */
    .detail-modal {
        width: 100%;
        max-width: 550px;
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
        padding: 1rem 2rem 0.8rem;
        text-align: center;
        border-bottom: 1px solid rgba(255, 255, 255, 0.05);
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 0.75rem;
    }
    .detail-icon {
        font-size: 1.5rem;
        color: var(--color-primary);
        text-shadow: 0 0 30px rgba(0, 255, 65, 0.5);
    }
    .detail-title {
        font-size: 1.2rem;
        font-weight: 700;
        color: #fff;
        letter-spacing: 2px;
    }
    .detail-body {
        padding: 1rem 1.5rem 1.5rem;
    }
    .detail-grid {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 0.5rem;
        margin-bottom: 0.75rem;
    }
    .detail-stat {
        background: rgba(0, 0, 0, 0.3);
        border: 1px solid rgba(255, 255, 255, 0.05);
        border-radius: 8px;
        padding: 0.6rem 0.4rem;
        text-align: center;
    }
    .stat-label {
        font-size: 0.5rem;
        color: #555;
        letter-spacing: 0.5px;
        margin-bottom: 0.2rem;
    }
    .stat-value {
        font-size: 0.75rem;
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
