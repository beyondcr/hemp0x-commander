<script>
    import { onMount } from "svelte";
    import { fly } from "svelte/transition";
    import { core } from "@tauri-apps/api";

    let activeSubTab = "ISSUE"; // TRANSFER, ISSUE, REISSUE
    let selectedAsset = "No Asset Selected";
    let myAssets = [];
    let tauriReady = false;
    let status = "";
    let transferTo = "";
    let transferAmt = "";

    let issueName = "";
    let issueQty = "1";
    let issueUnits = "0";
    let issueReissue = true;
    let confirmIssueOpen = false;
    let confirmIssuePayload = null;
    export let isNodeOnline = false; // Received from App.svelte

    function selectAsset(name) {
        selectedAsset = name;
    }

    async function refreshAssets() {
        if (!tauriReady) return;
        try {
            myAssets = await core.invoke("list_assets");
            isNodeOnline = true; // Node responded successfully
        } catch (err) {
            console.warn("Backend inactive or empty", err);
            const errStr = String(err || "");
            if (errStr.includes("couldn't connect") || errStr.includes("EOF")) {
                status = "Node offline - Start node to manage assets";
                isNodeOnline = false;
            } else {
                status = "Ready (No Assets Found)";
                isNodeOnline = true; // Node responded, just no assets
            }
            myAssets = [];
        }
    }

    async function submitTransfer() {
        if (!tauriReady) {
            status = "Backend unavailable.";
            return;
        }
        if (
            !transferTo ||
            !transferAmt ||
            selectedAsset === "No Asset Selected"
        ) {
            status = "Select asset, address, and amount.";
            return;
        }

        try {
            const txid = await core.invoke("transfer_asset", {
                asset: selectedAsset,
                amount: transferAmt,
                to: transferTo,
            });
            status = `Transferred. TXID: ${txid}`;
        } catch (err) {
            status = `Error: ${err}`;
        }
    }

    async function submitIssue() {
        if (!tauriReady) {
            status = "Backend unavailable.";
            return;
        }
        if (!issueName || !issueQty) {
            status = "Asset name and quantity required.";
            return;
        }

        const unitsValue = Number(issueUnits);
        if (!Number.isFinite(unitsValue) || unitsValue < 0 || unitsValue > 8) {
            status = "Units must be a number between 0 and 8.";
            return;
        }
        confirmIssuePayload = {
            name: issueName,
            qty: issueQty,
            units: unitsValue,
            reissuable: issueReissue,
        };
        confirmIssueOpen = true;
    }

    async function confirmIssue() {
        if (!confirmIssuePayload) return;
        try {
            const txid = await core.invoke("issue_asset", {
                name: confirmIssuePayload.name,
                qty: confirmIssuePayload.qty,
                units: confirmIssuePayload.units,
                reissuable: confirmIssuePayload.reissuable,
            });
            status = `Issued. TXID: ${txid}`;
            issueName = "";
            issueQty = "1";
            issueUnits = "0";
            issueReissue = true;
            await refreshAssets();
        } catch (err) {
            status = `Error: ${err}`;
        } finally {
            confirmIssueOpen = false;
            confirmIssuePayload = null;
        }
    }

    function cancelIssue() {
        confirmIssueOpen = false;
        confirmIssuePayload = null;
        status = "Asset mint cancelled.";
    }

    onMount(() => {
        tauriReady =
            typeof core?.isTauri === "function" ? core.isTauri() : false;

        // ONLY fetch if node is actually running
        if (isNodeOnline) {
            refreshAssets();
        } else {
            status = "Node offline - Start node to manage assets";
            myAssets = [];
        }
    });

    // React to online status changes
    $: if (tauriReady) {
        if (isNodeOnline) {
            refreshAssets();
        } else {
            myAssets = []; // Clear old data if node stops
            status = "Node offline - Start node to manage assets";
        }
    }
</script>

<div class="view-assets">
    <!-- TOP: MY ASSETS -->
    <div class="glass-panel panel-strong list-area cyber-panel">
        <header class="panel-header">
            <span class="hud-title mono">[ ASSET DATABASE ]</span>
            <span class="hint mono">SELECT TO MANAGE</span>
        </header>

        <!-- TECH TABLE HEADER -->
        <div class="header-row asset-grid-header">
            <span>NAME</span>
            <span>BALANCE</span>
            <span>TYPE</span>
        </div>

        <div class="scroll-body">
            {#each myAssets as item, i}
                <div
                    class="data-row asset-row"
                    class:selected={selectedAsset === item.name}
                    role="button"
                    tabindex="0"
                    on:click={() => selectAsset(item.name)}
                    on:keydown={(e) =>
                        (e.key === "Enter" || e.key === " ") &&
                        selectAsset(item.name)}
                    in:fly={{ y: 20, delay: i * 50, duration: 300 }}
                >
                    <span class="mono name">{item.name}</span>
                    <span class="mono val">{item.balance}</span>
                    <span class="type-tag">{item.type}</span>
                </div>
            {/each}
        </div>
    </div>

    <!-- BOTTOM: ACTIONS -->
    <div class="glass-panel panel-strong action-area cyber-panel">
        <header class="panel-header no-border">
            <div class="sub-tabs">
                {#each ["TRANSFER", "ISSUE", "REISSUE"] as tab}
                    <button
                        class="sub-tab-btn"
                        class:active={activeSubTab === tab}
                        on:click={() => (activeSubTab = tab)}
                    >
                        {tab}
                    </button>
                {/each}
            </div>
        </header>

        <div class="action-body">
            {#key activeSubTab}
                <div
                    class="transition-wrapper"
                    in:fly={{ y: 20, duration: 300 }}
                >
                    {#if activeSubTab === "TRANSFER"}
                        <!-- WIDE LAYOUT FOR TRANSFER -->
                        <div class="form-container">
                            <div class="info-bar">
                                <div class="info-label">TARGET ASSET:</div>
                                <div class="info-value neon-text">
                                    {selectedAsset}
                                </div>
                            </div>

                            <div class="fields-row">
                                <div class="field-group grow">
                                    <label for="asset-to" class="field-label"
                                        >RECIPIENT ADDRESS</label
                                    >
                                    <div class="input-wrapper brackets">
                                        <input
                                            id="asset-to"
                                            type="text"
                                            class="input-glass mono"
                                            placeholder="Enter HEMP0x Address..."
                                            bind:value={transferTo}
                                        />
                                    </div>
                                </div>
                                <div class="field-group fixed-width">
                                    <label
                                        for="asset-amount"
                                        class="field-label">AMOUNT</label
                                    >
                                    <div class="input-wrapper brackets">
                                        <input
                                            id="asset-amount"
                                            type="text"
                                            class="input-glass mono"
                                            placeholder="0.00"
                                            bind:value={transferAmt}
                                        />
                                    </div>
                                </div>
                            </div>

                            <div class="action-footer">
                                <button
                                    class="btn-action cyber-btn wide"
                                    class:disabled={!isNodeOnline}
                                    disabled={!isNodeOnline}
                                    on:click={submitTransfer}
                                >
                                    {isNodeOnline
                                        ? "[ INITIATE TRANSFER ]"
                                        : "[ NOT CONNECTED ]"}
                                </button>
                            </div>
                        </div>
                    {:else if activeSubTab === "ISSUE"}
                        <!-- WIDE LAYOUT FOR ISSUE -->
                        <div class="form-container">
                            <div class="top-row">
                                <div class="cost-badge">
                                    <span class="cost-label">COST:</span>
                                    <span class="cost-val">.25 HEMP</span>
                                </div>
                                <div class="field-group grow">
                                    <label for="asset-name" class="field-label"
                                        >ASSET NAME (UNIQUE)</label
                                    >
                                    <div class="input-wrapper brackets">
                                        <input
                                            id="asset-name"
                                            type="text"
                                            class="input-glass mono"
                                            placeholder="MY_TOKEN"
                                            bind:value={issueName}
                                        />
                                    </div>
                                </div>
                            </div>

                            <div class="fields-row">
                                <div class="field-group grow">
                                    <label for="asset-qty" class="field-label"
                                        >QUANTITY</label
                                    >
                                    <div class="input-wrapper brackets">
                                        <input
                                            id="asset-qty"
                                            type="text"
                                            class="input-glass mono"
                                            bind:value={issueQty}
                                        />
                                    </div>
                                </div>
                                <div class="field-group fixed-small">
                                    <label for="asset-units" class="field-label"
                                        >UNITS (0-8)</label
                                    >
                                    <div class="input-wrapper brackets">
                                        <input
                                            id="asset-units"
                                            type="number"
                                            class="input-glass mono"
                                            bind:value={issueUnits}
                                            max="8"
                                        />
                                    </div>
                                </div>
                                <div class="field-group checkbox-group">
                                    <label class="check-box-wrapper">
                                        <input
                                            type="checkbox"
                                            bind:checked={issueReissue}
                                        />
                                        <div class="check-visual"></div>
                                        <span class="check-text"
                                            >REISSUABLE</span
                                        >
                                    </label>
                                </div>
                            </div>

                            <div class="action-footer">
                                <button
                                    class="btn-action cyber-btn wide"
                                    class:disabled={!isNodeOnline}
                                    disabled={!isNodeOnline}
                                    on:click={submitIssue}
                                >
                                    {isNodeOnline
                                        ? "[ MINT ASSET ]"
                                        : "[ NOT CONNECTED ]"}
                                </button>
                            </div>
                        </div>
                    {:else}
                        <div class="center-msg mono dim">
                            REISSUE FUNCTIONALITY OFFLINE
                        </div>
                    {/if}
                </div>
            {/key}
        </div>
        {#if status}
            <div
                class="status-bar mono"
                class:error={status.startsWith("Error")}
                role="status"
            >
                <span class="blink">></span>
                {status}
            </div>
        {/if}
    </div>

    {#if confirmIssueOpen && confirmIssuePayload}
        <div class="confirm-backdrop" role="dialog" aria-modal="true">
            <div class="confirm-panel">
                <div class="confirm-title">Mint Asset Confirmation</div>
                <div class="confirm-body mono">
                    <div>
                        <span class="label">Name:</span>
                        {confirmIssuePayload.name}
                    </div>
                    <div>
                        <span class="label">Quantity:</span>
                        {confirmIssuePayload.qty}
                    </div>
                    <div>
                        <span class="label">Units:</span>
                        {confirmIssuePayload.units}
                    </div>
                    <div>
                        <span class="label">Reissuable:</span>
                        {confirmIssuePayload.reissuable ? "Yes" : "No"}
                    </div>
                </div>
                <div class="confirm-actions">
                    <button class="cyber-btn ghost" on:click={cancelIssue}>
                        CANCEL
                    </button>
                    <button class="cyber-btn" on:click={confirmIssue}>
                        CONFIRM
                    </button>
                </div>
            </div>
        </div>
    {/if}
</div>

<style>
    .view-assets {
        display: flex;
        flex-direction: column;
        gap: 1.2rem;
        height: 100%;
        min-height: 0;
        flex: 1; /* KEY FIX: Fill vertical space */
    }

    /* --- LAYOUT --- */
    .list-area {
        flex: 0 0 280px; /* Fixed height: Approx 5 items + header */
        min-height: 0;
    }
    .action-area {
        flex: 1; /* Grows to fill the rest of the window */
        display: flex;
        flex-direction: column;
        overflow: hidden;
    }

    /* --- CYBER PANEL --- */
    .cyber-panel {
        background: rgba(8, 12, 10, 0.85);
        border: 1px solid rgba(0, 255, 65, 0.2);
        box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6);
        position: relative;
        overflow: hidden;
        display: flex;
        flex-direction: column;
    }

    .panel-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 0.8rem 1.2rem;
        background: rgba(0, 0, 0, 0.4);
        border-bottom: 1px solid rgba(255, 255, 255, 0.05);
        flex-shrink: 0;
    }
    .panel-header.no-border {
        border-bottom: none;
        padding: 0;
    }
    .hud-title {
        color: var(--color-muted);
        font-size: 0.75rem;
        letter-spacing: 2px;
    }
    .hint {
        color: #555;
        font-size: 0.65rem;
    }

    /* --- ASSET LIST (Grid Table) --- */
    .asset-grid-header {
        display: grid;
        grid-template-columns: 1fr 1fr 100px;
        padding: 0.6rem 1.2rem;
        border-bottom: 1px solid rgba(0, 255, 65, 0.15);
        background: rgba(0, 255, 65, 0.02);
        color: var(--color-muted);
        font-size: 0.7rem;
        font-weight: bold;
        letter-spacing: 1px;
    }
    .scroll-body {
        flex: 1;
        overflow-y: scroll;
        min-height: 0;
        /* Global scrollbar style will apply */
        border-right: 1px solid rgba(255, 255, 255, 0.02);
    }

    .data-row {
        display: grid;
        grid-template-columns: 1fr 1fr 100px; /* Match header */
        padding: 0.8rem 1.2rem;
        border-bottom: 1px solid rgba(255, 255, 255, 0.03);
        align-items: center;
        transition: all 0.2s;
        cursor: pointer;
    }
    .data-row:hover {
        background: rgba(0, 255, 65, 0.05);
    }
    .data-row.selected {
        background: rgba(0, 255, 65, 0.1);
        border-left: 2px solid var(--color-primary);
    }
    .data-row .name {
        color: #fff;
        font-weight: bold;
        font-size: 0.9rem;
    }
    .data-row .val {
        color: var(--color-primary);
        font-size: 0.9rem;
    }
    .type-tag {
        font-size: 0.6rem;
        text-transform: uppercase;
        color: #888;
        border: 1px solid #444;
        padding: 2px 6px;
        border-radius: 4px;
        text-align: center;
        width: fit-content;
    }

    /* --- SUB TABS --- */
    .sub-tabs {
        display: flex;
        width: 100%;
        background: rgba(0, 0, 0, 0.3);
        border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    }
    .sub-tab-btn {
        flex: 1;
        background: transparent;
        border: none;
        color: var(--color-muted);
        padding: 1rem;
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

    /* --- ACTION BODY --- */
    .action-body {
        padding: 1.5rem 2rem;
        flex: 1;
        overflow: hidden;
        position: relative; /* Context for absolute transitions if needed */
    }

    /* --- FORM LAYOUTS (Horizontal Optimization) --- */
    .form-container {
        display: flex;
        flex-direction: column;
        gap: 1.2rem;
        padding: 0.5rem 0;
        height: 100%;
        justify-content: center; /* Center form vertically in panel */
    }

    .fields-row {
        display: flex;
        gap: 1.5rem;
        align-items: flex-start;
    }
    .top-row {
        display: flex;
        gap: 1.5rem;
        align-items: flex-end;
    }

    .field-group {
        display: flex;
        flex-direction: column;
        gap: 0.4rem;
    }
    .field-group.grow {
        flex: 1;
    }
    .field-group.fixed-width {
        width: 180px;
    }
    .field-group.fixed-small {
        width: 120px;
    }

    /* INFO BAR */
    .info-bar {
        display: flex;
        align-items: center;
        gap: 1rem;
        padding: 0.8rem;
        background: rgba(0, 255, 65, 0.03);
        border-left: 3px solid var(--color-primary);
        border-radius: 4px;
        margin-bottom: 0.5rem;
    }
    .info-label {
        font-size: 0.75rem;
        color: var(--color-muted);
        letter-spacing: 1px;
    }
    .info-value {
        font-size: 1.1rem;
        font-weight: 600;
        letter-spacing: 1px;
    }

    /* COST BADGE */
    .cost-badge {
        display: flex;
        flex-direction: column;
        justify-content: center;
        background: rgba(255, 255, 255, 0.03);
        border: 1px solid rgba(255, 255, 255, 0.1);
        padding: 0.6rem 1rem;
        border-radius: 6px;
        height: 52px; /* Match input height roughly */
        margin-bottom: 1px;
    }
    .cost-label {
        font-size: 0.6rem;
        color: #ff8888;
        letter-spacing: 1px;
    }
    .cost-val {
        font-size: 0.9rem;
        font-weight: bold;
        color: #fff;
    }

    /* CHECKBOX STYLING */
    .checkbox-group {
        justify-content: center;
        height: 70px; /* Align with inputs */
    }
    .check-box-wrapper {
        display: flex;
        align-items: center;
        gap: 0.8rem;
        cursor: pointer;
        background: rgba(0, 0, 0, 0.3);
        padding: 0.8rem 1rem;
        border-radius: 6px;
        border: 1px solid rgba(255, 255, 255, 0.1);
        transition: all 0.2s;
    }
    .check-box-wrapper:hover {
        border-color: var(--color-primary);
    }
    .check-box-wrapper input {
        display: none;
    }
    .check-visual {
        width: 18px;
        height: 18px;
        border: 2px solid #555;
        border-radius: 4px;
        position: relative;
    }
    .check-box-wrapper input:checked + .check-visual {
        background: var(--color-primary);
        border-color: var(--color-primary);
        box-shadow: 0 0 8px var(--color-primary);
    }
    .check-text {
        font-size: 0.8rem;
        color: var(--color-muted);
        letter-spacing: 1px;
    }
    .check-box-wrapper input:checked ~ .check-text {
        color: #fff;
    }

    /* INPUTS */
    .field-label {
        font-size: 0.7rem;
        color: var(--color-muted);
        letter-spacing: 1.5px;
        margin-left: 4px;
    }
    .input-wrapper {
        position: relative;
        width: 100%;
    }
    .input-glass {
        width: 100%;
        background: rgba(0, 0, 0, 0.4);
        border: 1px solid rgba(255, 255, 255, 0.15);
        color: #fff;
        caret-color: var(--color-primary);
        padding: 0.8rem 1rem;
        font-size: 1rem;
        border-radius: 6px;
        outline: none;
        transition: all 0.2s;
    }
    .input-glass:focus {
        border-color: var(--color-primary);
        box-shadow: 0 0 15px rgba(0, 255, 65, 0.15);
        background: rgba(0, 0, 0, 0.6);
    }
    .input-glass:-webkit-autofill,
    .input-glass:-webkit-autofill:hover,
    .input-glass:-webkit-autofill:focus {
        -webkit-text-fill-color: #fff;
        box-shadow: 0 0 0px 1000px rgba(0, 0, 0, 0.85) inset;
        border: 1px solid rgba(255, 255, 255, 0.2);
    }

    /* BUTTONS */
    .action-footer {
        margin-top: 0.5rem;
        display: flex;
        justify-content: flex-end;
    }
    .cyber-btn {
        background: rgba(0, 255, 65, 0.05);
        border: 1px solid var(--color-primary);
        color: var(--color-primary);
        padding: 1rem 2rem;
        letter-spacing: 2px;
        font-weight: bold;
        transition: all 0.2s;
        cursor: pointer;
        text-transform: uppercase;
        position: relative;
        overflow: hidden;
    }
    .cyber-btn:hover {
        background: var(--color-primary);
        color: #000;
        box-shadow: 0 0 25px rgba(0, 255, 65, 0.5);
        transform: translateY(-2px);
    }

    .confirm-backdrop {
        position: fixed;
        inset: 0;
        background: rgba(0, 0, 0, 0.7);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 999;
        backdrop-filter: blur(4px);
    }
    .confirm-panel {
        width: min(520px, 90vw);
        background: rgba(0, 0, 0, 0.85);
        border: 1px solid rgba(0, 255, 65, 0.35);
        box-shadow:
            0 0 25px rgba(0, 255, 65, 0.2),
            inset 0 0 20px rgba(0, 0, 0, 0.6);
        border-radius: 12px;
        padding: 1.4rem 1.6rem;
    }
    .confirm-title {
        color: var(--color-primary);
        font-weight: 700;
        letter-spacing: 1px;
        margin-bottom: 1rem;
        text-transform: uppercase;
    }
    .confirm-body {
        display: grid;
        gap: 0.4rem;
        color: #cfd9cf;
        font-size: 0.95rem;
        margin-bottom: 1.2rem;
    }
    .confirm-body .label {
        color: #6fae7c;
        margin-right: 0.4rem;
    }
    .confirm-actions {
        display: flex;
        justify-content: flex-end;
        gap: 0.8rem;
    }
    .cyber-btn.wide {
        width: 100%;
        text-align: center;
    }
    .cyber-btn.disabled,
    .cyber-btn:disabled {
        background: rgba(100, 100, 100, 0.2);
        border-color: #555;
        color: #666;
        cursor: not-allowed;
        box-shadow: none;
    }
    .cyber-btn.disabled:hover,
    .cyber-btn:disabled:hover {
        background: rgba(100, 100, 100, 0.2);
        color: #666;
        transform: none;
        box-shadow: none;
    }

    /* --- BASIC --- */
    .neon-text {
        color: var(--color-primary);
        text-shadow: 0 0 5px rgba(0, 255, 65, 0.5);
        font-family: var(--font-mono);
    }

    /* STATUS BAR */
    .status-bar {
        margin: 0;
        padding: 0.6rem 1rem;
        background: rgba(0, 0, 0, 0.4);
        border-top: 1px solid rgba(255, 255, 255, 0.05);
        color: var(--color-primary);
        font-size: 0.75rem;
        flex-shrink: 0;
    }
    .status-bar.error {
        color: #ff5555;
    }
    .blink {
        animation: blink 1s infinite;
    }
    .center-msg {
        display: flex;
        justify-content: center;
        align-items: center;
        height: 100%;
        text-align: center;
    }
    @keyframes blink {
        50% {
            opacity: 0;
        }
    }

    /* GLOBAL SCROLLBAR OVERRIDES RE-APPLY (Just in case) */
    .scroll-body::-webkit-scrollbar {
        width: 8px;
    }
    .scroll-body::-webkit-scrollbar-track {
        background: rgba(0, 255, 65, 0.06);
        border-left: 1px solid rgba(0, 255, 65, 0.1);
    }
    .scroll-body::-webkit-scrollbar-thumb {
        background: rgba(0, 255, 65, 0.3);
        border-radius: 0;
    }
</style>
