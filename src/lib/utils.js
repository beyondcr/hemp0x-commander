/**
 * Format a balance for display.
 * - < 10,000: Full precision (8 decimals), strip trailing zeros.
 * - 10k - 1M: 1 decimal place with 'K' suffix.
 * - 1M - 1B: 2 decimal places with 'M' suffix.
 * - > 1B: 2 decimal places with 'B' suffix.
 * @param {string|number} balance
 * @returns {string}
 */
export function formatBalance(balance) {
    const num = parseFloat(balance);
    if (isNaN(num)) return String(balance);

    const absNum = Math.abs(num);

    if (absNum >= 1_000_000_000) {
        return (num / 1_000_000_000).toFixed(2).replace(/\.?0+$/, "") + "B";
    } else if (absNum >= 1_000_000) {
        return (num / 1_000_000).toFixed(2).replace(/\.?0+$/, "") + "M";
    } else if (absNum >= 10_000) {
        return (num / 1_000).toFixed(1).replace(/\.?0+$/, "") + "K";
    } else {
        return num.toFixed(8).replace(/\.?0+$/, "");
    }
}

/**
 * Format a raw amount with commas for standard display (no suffix)
 * @param {string|number} amount 
 * @returns {string}
 */
export function formatAmount(amount) {
    const num = parseFloat(amount);
    if (isNaN(num)) return "0.00";
    return num.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 8 });
}
