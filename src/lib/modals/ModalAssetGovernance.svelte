<script>
    import { createEventDispatcher } from "svelte";
    import { fade, scale } from "svelte/transition";
    import { invoke } from "@tauri-apps/api/core";
    import "../../components.css";
    import ModalAlert from "./ModalAlert.svelte";

    export let isOpen = false;
    export let asset; // { name, balance, hasOwner, reissuable, ipfs_hash, ... }

    const dispatch = createEventDispatcher();

    let activeTab = "transfer"; // transfer, lock, metadata
    let newOwnerAddress = "";
    let newIpfsHash = "";

    // Safety & Loading State
    let lockConfirmed = false;
    let isSubmitting = false;
    let lockHoldSeconds = 10;
    let isHolding = false;
    let holdTimer;

    // Alert State
    let alertOpen = false;
    let alertTitle = "";
    let alertMessage = "";
    let alertType = "info";
    let shouldCloseOnAlertDismiss = false;

    function startHold() {
        if (!lockConfirmed || isSubmitting) return;
        isHolding = true;
        lockHoldSeconds = 10;

        holdTimer = setInterval(() => {
            lockHoldSeconds--;
            if (lockHoldSeconds <= 0) {
                stopHold();
                handleLock();
            }
        }, 1000);
    }

    function stopHold() {
        if (holdTimer) clearInterval(holdTimer);
        isHolding = false;
        lockHoldSeconds = 10;
    }

    $: if (isOpen && asset) {
        newIpfsHash = asset?.ipfs_hash || "";
        lockConfirmed = false;
        isSubmitting = false;
    }

    function close() {
        dispatch("close");
    }

    function triggerAlert(title, message, type = "info", closeParent = false) {
        alertTitle = title;
        alertMessage = message;
        alertType = type;
        shouldCloseOnAlertDismiss = closeParent;
        alertOpen = true;
    }

    function handleAlertClose() {
        alertOpen = false;
        if (shouldCloseOnAlertDismiss) {
            close();
        }
    }

    async function handleTransfer() {
        if (!newOwnerAddress) return;
        isSubmitting = true;
        try {
            const ownerToken = (asset?.name || "") + "!";
            await invoke("transfer_asset", {
                asset: ownerToken,
                amount: "1.0",
                to: newOwnerAddress,
            });
            triggerAlert(
                "Ownership Transferred",
                "You have successfully transferred ownership. You no longer control this asset.",
                "success",
                true, // Close modal after OK
            );
        } catch (e) {
            triggerAlert("Error", e.toString(), "error");
        } finally {
            isSubmitting = false;
        }
    }

    async function handleLock() {
        if (!lockConfirmed) return;
        isSubmitting = true;
        try {
            const units = asset?.units ?? 8;
            await invoke("lock_asset_supply", {
                name: asset?.name || "",
                currentUnits: units,
            });
            triggerAlert(
                "Supply Locked",
                "The asset supply has been permanently locked.",
                "success",
                true,
            );
        } catch (e) {
            triggerAlert("Error", e.toString(), "error");
        } finally {
            isSubmitting = false;
        }
    }

    async function handleMetadata() {
        isSubmitting = true;
        try {
            const units = asset?.units ?? 8;
            await invoke("update_asset_metadata", {
                name: asset?.name || "",
                ipfsHash: newIpfsHash,
                currentUnits: units,
            });
            triggerAlert(
                "Metadata Updated",
                "Asset metadata has been updated on the blockchain.",
                "success",
                true,
            );
        } catch (e) {
            triggerAlert("Error", e.toString(), "error");
        } finally {
            isSubmitting = false;
        }
    }
</script>

{#if isOpen}
    <div
        class="modal-backdrop"
        role="button"
        tabindex="0"
        on:click={close}
        on:keydown={(e) => e.key === "Escape" && close()}
        transition:fade={{ duration: 200 }}
    >
        <div
            class="modal glass-panel"
            role="dialog"
            aria-modal="true"
            tabindex="-1"
            on:click|stopPropagation
            on:keydown={() => {}}
            transition:scale={{ duration: 200, start: 0.95 }}
        >
            <div class="modal-header">
                <h3>{asset ? asset.name : ""}</h3>
                <button class="close-btn" on:click={close}>&times;</button>
            </div>

            <!-- Tabs -->
            <div class="tabs">
                <button
                    class:active={activeTab === "transfer"}
                    on:click={() => (activeTab = "transfer")}
                    >Transfer Owner</button
                >
                <button
                    class:active={activeTab === "metadata"}
                    on:click={() => (activeTab = "metadata")}>Metadata</button
                >
                <button
                    class:active={activeTab === "lock"}
                    on:click={() => (activeTab = "lock")}
                    class="tab-danger">Lock Supply</button
                >
            </div>

            <div class="modal-body">
                <!-- Inline alerts removed in favor of ModalAlert -->

                {#if activeTab === "transfer"}
                    <div class="panel">
                        <!-- ... content ... -->
                        <p class="section-desc">
                            Send the <strong
                                >Administrator Token ({asset
                                    ? asset.name
                                    : ""}!)</strong
                            > to another wallet. You will lose all control.
                        </p>
                        <label for="owner-address">New Owner Address</label>
                        <input
                            id="owner-address"
                            type="text"
                            bind:value={newOwnerAddress}
                            placeholder="H..."
                            class="cyber-input"
                        />
                        <div class="actions">
                            <button
                                class="cyber-btn"
                                on:click={handleTransfer}
                                disabled={isSubmitting || !newOwnerAddress}
                            >
                                {isSubmitting
                                    ? "Transferring..."
                                    : "Transfer Ownership"}
                            </button>
                        </div>
                    </div>
                {:else if activeTab === "metadata"}
                    <div class="panel">
                        <p class="section-desc">
                            Update the IPFS hash associated with this asset.
                        </p>
                        <label for="ipfs-hash">New IPFS Hash / Data</label>
                        <input
                            id="ipfs-hash"
                            type="text"
                            bind:value={newIpfsHash}
                            placeholder="Qm..."
                            class="cyber-input"
                        />
                        <div class="actions">
                            <button
                                class="cyber-btn"
                                on:click={handleMetadata}
                                disabled={isSubmitting}
                            >
                                {isSubmitting
                                    ? "Updating..."
                                    : "Update Metadata"}
                            </button>
                        </div>
                    </div>
                {:else if activeTab === "lock"}
                    <div class="panel danger-zone">
                        <div class="warning-icon">⚠️</div>
                        <h4>Danger Zone</h4>
                        <p>
                            This will <strong>PERMANENTLY LOCK</strong> the
                            supply of {asset ? asset.name : ""}.
                        </p>
                        <p>
                            No more tokens can ever be minted. This action
                            cannot be undone.
                        </p>

                        <label class="confirm-check">
                            <input
                                type="checkbox"
                                bind:checked={lockConfirmed}
                            />
                            <span>I understand this is permanent.</span>
                        </label>

                        <div class="actions">
                            <button
                                class="cyber-btn danger"
                                on:mousedown={startHold}
                                on:touchstart={startHold}
                                on:mouseup={stopHold}
                                on:touchend={stopHold}
                                on:mouseleave={stopHold}
                                disabled={!lockConfirmed || isSubmitting}
                                style={isHolding
                                    ? "transform: scale(0.98); opacity: 0.9;"
                                    : ""}
                            >
                                {#if isSubmitting}
                                    LOCKING...
                                {:else if isHolding}
                                    HOLD TO LOCK ({lockHoldSeconds}s)...
                                {:else}
                                    HOLD 10s TO LOCK FOREVER
                                {/if}
                            </button>
                        </div>
                    </div>
                {/if}
            </div>
        </div>
    </div>

    <!-- Alert Modal for Success/Error -->
    <ModalAlert
        isOpen={alertOpen}
        title={alertTitle}
        message={alertMessage}
        type={alertType}
        on:close={handleAlertClose}
    />
{/if}

<style>
    .modal-backdrop {
        position: fixed;
        inset: 0;
        background: rgba(0, 0, 0, 0.85);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 200000; /* Must be > 99999 (Detail Modal) */
        backdrop-filter: blur(5px);
    }
    .modal {
        width: 460px; /* Slightly narrower */
        max-width: 90vw;
        border: 1px solid rgba(0, 255, 65, 0.2);
        box-shadow: 0 0 30px rgba(0, 0, 0, 0.8);
        border-radius: 16px;
        overflow: hidden;
        display: flex;
        flex-direction: column;
    }

    @media (max-height: 700px) {
        .modal-body {
            min-height: 300px;
            overflow-y: auto;
        }
    }
    .modal-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 0.8rem 1.25rem;
        background: rgba(0, 0, 0, 0.3);
        border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    }
    .modal-header h3 {
        margin: 0;
        color: var(--color-primary);
        text-shadow: 0 0 10px rgba(0, 255, 65, 0.3);
        font-size: 1.1rem;
    }
    /* ... */
    .modal-body {
        padding: 1.25rem;
        min-height: 310px; /* Fixed height to accommodate Lock Tab without jumping */
        display: flex;
        flex-direction: column;
        justify-content: center;
    }
    .section-desc {
        color: #aaa;
        font-size: 0.85rem;
        margin-bottom: 1rem;
        line-height: 1.3;
    }
    .cyber-input {
        width: 100%;
        padding: 0.6rem;
        margin-bottom: 1rem;
        background: rgba(0, 0, 0, 0.4);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 4px;
        color: #fff;
        font-family: var(--font-mono);
    }
    .cyber-input:focus {
        border-color: var(--color-primary);
        outline: none;
    }
    .actions {
        display: flex;
        justify-content: flex-end;
    }
    .danger-zone {
        border: 1px solid rgba(255, 0, 0, 0.2);
        background: rgba(255, 0, 0, 0.05);
        padding: 1rem; /* Compact padding */
        border-radius: 8px;
        text-align: center;
    }
    .danger-zone h4 {
        color: #ff3333;
        margin: 0.2rem 0; /* Tighter */
        font-size: 1rem;
    }
    .danger-zone p {
        color: #ddd;
        font-size: 0.85rem;
        margin-bottom: 0.5rem;
    }
    .warning-icon {
        font-size: 1.5rem; /* Smaller icon */
        margin-bottom: 0.2rem;
    }
    .cyber-btn.danger {
        border-color: #ff3333;
        color: #ff3333;
        box-shadow: none;
    }
    .cyber-btn.danger:hover:not(:disabled) {
        background: #ff3333;
        color: #fff;
        box-shadow: 0 0 15px rgba(255, 0, 0, 0.4);
    }
    .confirm-check {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 0.5rem;
        margin: 0.8rem 0; /* Compact margin */
        cursor: pointer;
        color: #ffaaaa;
        font-size: 0.85rem;
    }
</style>
