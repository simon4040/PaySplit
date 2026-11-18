import { config } from '@/config'
import { buildAddressExplorerUrl as registryAddressUrl, buildTxExplorerUrl as registryTxUrl } from '@/onchain-facts'

/**
 * Explorer links that never throw. The generated chain registry may not know a network (for example Arbitrum One);
 * in that case the explorer comes from the wallet-chain definition in src/config.ts. Null = no known explorer.
 */
function fallbackBase(chainId: number): string | null {
  const url = config.chains.find(c => c.id === chainId)?.blockExplorers?.default.url
  return url ? url.replace(/\/$/, '') : null
}

export function explorerAddressUrl(chainId: number, address: string): string | null {
  try {
    return registryAddressUrl(chainId, address)
  } catch {
    const base = fallbackBase(chainId)
    return base ? `${base}/address/${address}` : null
  }
}

export function explorerTxUrl(chainId: number, txHash: string): string | null {
  try {
    return registryTxUrl(chainId, txHash)
  } catch {
    const base = fallbackBase(chainId)
    return base ? `${base}/tx/${txHash}` : null
  }
}
