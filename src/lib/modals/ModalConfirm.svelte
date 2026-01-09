<script>
    import { fly, fade } from "svelte/transition";

    export let isOpen = false;
    export let type = "";
    export let payload = {};

    import { createEventDispatcher } from "svelte";
    const dispatch = createEventDispatcher();

    function close() {
        dispatch("close");
    }

    function confirm() {
        dispatch("confirm");
    }
</script>

{#if isOpen}
    <div class="modal-overlay" transition:fade={{ duration: 100 }}>
        <div class="confirm-modal glass-modal" transition:fly={{ y: 15 }}>
            <div class="confirm-header">CONFIRM {type}</div>
            <div class="confirm-body">
                {#each Object.entries(payload) as [k, v]}
                    <div class="confirm-row">
                        <span class="row-key">{k}</span>
                        <span class="row-val">{v}</span>
                    </div>
                {/each}
            </div>
            <div class="confirm-footer">
                <button class="ghost-btn" on:click={close}>CANCEL</button>
                <button class="neon-btn sm" on:click={confirm}>CONFIRM</button>
            </div>
        </div>
    </div>
{/if}

<style>
    /* Confirm Modal */
    .confirm-modal {
        width: 100%;
        max-width: 360px;
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

    /* Buttons (Local copies to ensure self-containment if ViewAssets styles aren't global) */
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
    .neon-btn.sm {
        padding: 0.6rem 1.5rem;
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
</style>
