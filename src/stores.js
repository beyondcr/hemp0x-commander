import { writable } from 'svelte/store';

/**
 * System Status
 * Tracks the availability of the Tauri backend and core environment.
 */
export const systemStatus = writable({
    tauriReady: false,
    os: "unknown"
});

/**
 * Node Status
 * Tracks the connectivity and general health of the local Hemp0x node.
 */
export const nodeStatus = writable({
    online: false,
    version: "--",
    connections: 0,
    headers: 0,
    blocks: 0,
    verificationProgress: 0,
    error: null
});

/**
 * Network Info
 * Tracks blockchain specifics like chain type and difficulty.
 */
export const networkInfo = writable({
    chain: "mainnet",
    difficulty: 0,
    networkHashps: 0,
    testnet: false
});

/**
 * Wallet Info
 * Tracks financial data for the user.
 */
export const walletInfo = writable({
    balance: "--",
    unconfirmed: 0.0,
    immature: 0.0,
    transactions: [],
    newTxCount: 0,
    status: "--"
});

/**
 * Global UI State
 * Shared UI concerns like Toast notifications.
 */
export const uiState = writable({
    toast: null
});
