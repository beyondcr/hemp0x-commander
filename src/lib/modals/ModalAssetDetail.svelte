<script>
    import { fly, fade } from "svelte/transition";
    import { createEventDispatcher } from "svelte";
    import { formatBalance } from "../utils.js";
    import "../../components.css";
    import Tooltip from "../ui/Tooltip.svelte";
    import ModalAlert from "./ModalAlert.svelte";

    const dispatch = createEventDispatcher();

    export let asset;
    export let metadata;
    export let loading = false;
    export let slideDirection = 0;
    export let hasMultipleAssets = false;

    let showAlert = false;

    function close() {
        dispatch("close");
    }

    function next() {
        dispatch("next");
    }

    function prev() {
        dispatch("prev");
    }

    // Action dispatchers
    function onTransfer() {
        dispatch("transfer", asset);
    }

    function onReissue() {
        dispatch("reissue", asset);
    }

    function onSubAsset() {
        dispatch("createSub", asset);
    }

    function onNft() {
        dispatch("createNft", asset);
    }

    function onGovernance() {
        if (asset && asset.hasOwner) {
            dispatch("gov", asset);
        }
    }
</script>

{#if asset}
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <!-- svelte-ignore a11y-no-static-element-interactions -->
    <div
        class="modal-overlay"
        transition:fade={{ duration: 150 }}
        on:click={close}
        on:keydown={(e) => e.key === "Escape" && close()}
        role="button"
        tabindex="0"
    >
        <div class="modal-container">
            <!-- Navigation Arrows -->
            {#if hasMultipleAssets}
                <button
                    class="nav-arrow nav-prev"
                    on:click|stopPropagation={prev}
                    title="Previous Asset">«</button
                >
            {/if}

            {#key asset.name}
                <div
                    class="detail-modal glass-modal"
                    in:fly={{ x: slideDirection * 40, duration: 180 }}
                    out:fly={{
                        x: slideDirection * -40,
                        duration: 120,
                        opacity: 0,
                    }}
                    on:click|stopPropagation
                >
                    <button class="modal-close" on:click={close}>×</button>

                    <div class="detail-header">
                        <div class="detail-icon">◈</div>
                        <div class="detail-title">
                            {asset.name}
                        </div>
                    </div>

                    <div class="detail-body">
                        <div class="detail-grid">
                            <div class="detail-stat">
                                <div class="stat-label">YOUR BALANCE</div>
                                <div class="stat-value neon-text">
                                    {formatBalance(asset.balance)}
                                </div>
                            </div>
                            <div class="detail-stat">
                                <div class="stat-label">TYPE</div>
                                <div class="stat-value">
                                    {asset.isSubAsset
                                        ? "SUB-ASSET"
                                        : asset.type || "STANDARD"}
                                </div>
                            </div>
                            <div class="detail-stat">
                                <div class="stat-label">STATUS</div>
                                <div
                                    class="stat-value"
                                    class:owner-yes={asset.hasOwner}
                                    class:clickable={asset.hasOwner}
                                    role="button"
                                    tabindex={asset.hasOwner ? 0 : -1}
                                    title={asset.hasOwner
                                        ? "Manage Governance"
                                        : "Status"}
                                    on:click={onGovernance}
                                    on:keydown={(e) =>
                                        e.key === "Enter" && onGovernance()}
                                >
                                    {asset.hasOwner ? "👑 OWNER" : "🔒 LOCKED"}
                                </div>
                            </div>
                            <div class="detail-stat">
                                <div class="stat-label">DECIMALS</div>
                                <div class="stat-value">
                                    {metadata?.units ?? asset.units ?? 0}
                                </div>
                            </div>
                        </div>

                        <!-- Enhanced Metadata Section -->
                        {#if loading}
                            <div class="metadata-section">
                                <div class="meta-loading">
                                    Loading metadata...
                                </div>
                            </div>
                        {:else if metadata}
                            <div class="metadata-section">
                                <div class="meta-row">
                                    <span class="meta-label">TOTAL SUPPLY</span>
                                    <Tooltip
                                        text="Top 100 Holders (Coming Soon)"
                                    >
                                        <span
                                            class="meta-value clickable"
                                            role="button"
                                            tabindex="0"
                                            on:click={() => (showAlert = true)}
                                            on:keydown={(e) =>
                                                e.key === "Enter" &&
                                                (showAlert = true)}
                                            >{metadata.amount.toLocaleString()}</span
                                        >
                                    </Tooltip>
                                </div>
                                <div class="meta-row">
                                    <span class="meta-label">REISSUABLE</span>
                                    <span
                                        class="meta-value"
                                        class:yes={metadata.reissuable}
                                    >
                                        {metadata.reissuable ? "YES" : "NO"}
                                    </span>
                                </div>
                                {#if metadata.has_ipfs && metadata.ipfs_hash}
                                    <div class="meta-row">
                                        <span class="meta-label">IPFS</span>
                                        <span class="meta-value mono ipfs-hash"
                                            >{metadata.ipfs_hash}</span
                                        >
                                    </div>
                                {/if}
                                <div class="meta-row">
                                    <span class="meta-label"
                                        >CREATED AT BLOCK</span
                                    >
                                    <span class="meta-value"
                                        >{metadata.block_height.toLocaleString()}</span
                                    >
                                </div>
                            </div>
                        {/if}

                        <div class="detail-actions">
                            <button
                                class="action-btn primary"
                                on:click={onTransfer}
                            >
                                <span class="action-icon">→</span> TRANSFER
                            </button>
                            <button
                                class="action-btn"
                                class:disabled={!metadata?.reissuable}
                                on:click={onReissue}
                                disabled={!metadata?.reissuable}
                                title={!metadata?.reissuable
                                    ? "Asset supply is locked"
                                    : "Reissue Asset"}
                            >
                                <span class="action-icon">↻</span> REISSUE
                            </button>
                        </div>
                        {#if asset.hasOwner && !asset.name.includes("#")}
                            <div class="detail-actions owner-actions">
                                <button
                                    class="action-btn sub-btn"
                                    on:click={onSubAsset}
                                >
                                    <span class="action-icon">↳</span> CREATE SUB-ASSET
                                </button>
                                <button
                                    class="action-btn nft-btn"
                                    on:click={onNft}
                                >
                                    <span class="action-icon">#</span> MINT NFT
                                </button>
                            </div>
                        {/if}
                    </div>
                </div>
            {/key}

            <!-- Right Arrow -->
            {#if hasMultipleAssets}
                <button
                    class="nav-arrow nav-next"
                    on:click|stopPropagation={next}
                    title="Next Asset">»</button
                >
            {/if}
        </div>
    </div>

    <!-- Alert Modal for Coming Soon features -->
    <ModalAlert
        isOpen={showAlert}
        title="Coming Soon"
        message="Top 100 Holders list requires 'assetindex=1' node configuration. This feature is deferred."
        on:close={() => (showAlert = false)}
    />
{/if}

<style>
    /* Local Styles extracted from ViewAssets */
    .detail-modal {
        width: 100%;
        max-width: 550px;
        position: relative;
        background: rgba(10, 15, 12, 0.95);
        border: 1px solid rgba(0, 255, 65, 0.25);
        border-radius: 16px;
        box-shadow:
            0 0 80px rgba(0, 0, 0, 0.8),
            0 0 40px rgba(0, 255, 65, 0.1);
        overflow: hidden;
    }
    .modal-container {
        display: flex;
        align-items: center;
        gap: 1rem;
        /* Ensure it fits in viewport */
        max-width: 100vw;
        justify-content: center;
    }
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
    .action-btn.disabled {
        opacity: 0.5;
        cursor: not-allowed;
        filter: grayscale(1);
    }
    .action-btn.disabled:hover {
        background: rgba(255, 255, 255, 0.05);
        color: #fff;
        transform: none;
        box-shadow: none;
    }
    .stat-value.clickable {
        cursor: pointer;
        transition: all 0.2s;
        border: 1px solid transparent;
        border-radius: 4px;
        padding: 0 4px;
    }
    .stat-value.clickable:hover {
        background: rgba(255, 215, 0, 0.15);
        border-color: rgba(255, 215, 0, 0.3);
        transform: scale(1.05);
    }

    /* Actions */
    .detail-actions {
        display: flex;
        gap: 0.8rem;
    }
    .owner-actions {
        margin-top: 0.8rem;
    }
    .action-btn {
        flex: 1;
        background: rgba(255, 255, 255, 0.03);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 10px;
        padding: 0.6rem;
        color: #aaa;
        font-size: 0.65rem;
        font-weight: 600;
        letter-spacing: 1px;
        cursor: pointer;
        transition: all 0.15s;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 0.4rem;
        white-space: nowrap;
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

    /* Metadata */
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
</style>
