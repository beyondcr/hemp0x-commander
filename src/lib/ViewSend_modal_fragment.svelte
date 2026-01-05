<!-- UTXO SELECTION MODAL -->
{#if showUtxoModal}
    <div class="modal-overlay" on:click={() => (showUtxoModal = false)}>
        <div class="utxo-modal" on:click|stopPropagation>
            <div class="modal-header">
                <h2>SELECT COINS</h2>
                <div class="utxo-stats">
                    <span>SELECTED: {formatAmount(totalSelected)}</span>
                    <span>COUNT: {selectedUtxos.size}</span>
                </div>
            </div>

            <div class="utxo-list">
                <!-- DEBUG -->
                {#if utxos.length === 0}
                    <div style="color: red; padding: 1rem;">
                        NO UTXOS AVAILABLE (Length: 0)
                    </div>
                {/if}
                {#if utxos.length > 0}
                    <div
                        style="font-size: 0.6rem; color: #555; padding-bottom: 0.5rem;"
                    >
                        DEBUG FIRST: {JSON.stringify(utxos[0])}
                    </div>
                {/if}

                <table class="utxo-table">
                    <thead>
                        <tr>
                            <th></th>
                            <th>AMOUNT</th>
                            <th>ADDRESS</th>
                            <th>CONF</th>
                        </tr>
                    </thead>
                    <tbody>
                        {#each utxos as u}
                            <tr
                                class:selected={selectedUtxos.has(
                                    `${u.txid}:${u.vout}`,
                                )}
                                on:click={() => toggleUtxo(u)}
                            >
                                <td>
                                    <div
                                        class="checkbox"
                                        class:checked={selectedUtxos.has(
                                            `${u.txid}:${u.vout}`,
                                        )}
                                    ></div>
                                </td>
                                <td class="amount-cell"
                                    >{u.amount.toFixed(8)}</td
                                >
                                <td class="addr-cell">
                                    {#if u.address}
                                        {u.address.substring(0, 20)}...
                                    {:else}
                                        <span
                                            style="color: #666; font-style: italic;"
                                            >(Change Output)</span
                                        >
                                    {/if}
                                </td>
                                <td>{u.confirmations}</td>
                            </tr>
                        {/each}
                    </tbody>
                </table>
            </div>

            <div class="modal-footer">
                <button
                    class="btn-confirm"
                    on:click={() => (showUtxoModal = false)}>[ DONE ]</button
                >
            </div>
        </div>
    </div>
{/if}
