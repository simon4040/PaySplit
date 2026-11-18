/**
 * Bridge routes. Each network's StrPoints contract bridges to ONE fixed network: the CCTP domain it was
 * deployed with (`destinationDomain`). These helpers turn that domain into a network the app has live.
 * Kept free of React so the rules can be tested on their own.
 */
import { CHAINS, CHAIN_KEYS, type ChainKey } from '@/contract'

export interface RouteOption {
  key: ChainKey
  label: string
  /** True for the one network this deployment can bridge to. */
  supported: boolean
}

/** The live network a deployment bridges to, or null if its destination is not a live network. */
export function destinationFor(domain: number | undefined, from: ChainKey): ChainKey | null {
  if (domain === undefined) return null
  return CHAIN_KEYS.find(k => k !== from && CHAINS[k].cctpDomain === domain) ?? null
}

/** Every other live network, marking which one can be reached from `from`. */
export function routeOptions(from: ChainKey, domain: number | undefined): RouteOption[] {
  const dest = destinationFor(domain, from)
  return CHAIN_KEYS.filter(k => k !== from).map(k => ({ key: k, label: CHAINS[k].label, supported: k === dest }))
}
