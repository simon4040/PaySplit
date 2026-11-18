/**
 * Contract ABIs and the per-chain setup the whole app reads. Chain ids, token and contract addresses
 * come from src/network.ts; ABIs are the committed files in src/abi (refresh with `bun run abi:sync`).
 */
import splitFactory from './abi/SplitFactory.json'
import strPoints from './abi/StrPoints.json'
import splitNames from './abi/SplitNames.json'
import recipientLabels from './abi/RecipientLabels.json'
import feeRouter from './abi/FeeRouter.json'
import { NETWORK, type ChainDeployment } from './network'

export const SPLIT_ABI = splitFactory.abi
export const POINTS_ABI = strPoints.abi
export const NAMES_ABI = splitNames.abi
export const LABELS_ABI = recipientLabels.abi
export const ROUTER_ABI = feeRouter.abi

export interface StockToken {
  symbol: string
  name: string
  /** Zero address = this test token is not deployed yet. */
  address: `0x${string}`
  /** Illustrative USD price per token (test tokens only). */
  usdPrice?: number
}

/** Base-only Stock Treasury setup (chains without a `stock` entry in src/network.ts never get one). */
export interface StockSetup {
  /** The FeeRouter, or null until it is deployed. */
  router: { address: `0x${string}`; abi: typeof ROUTER_ABI } | null
  /** The planned stock treasury wallet (the router's own setting takes over once it exists). */
  treasury: `0x${string}`
  /** 'illustrative' = dollar values use placeholder prices and must be labelled as such. */
  priceBasis: 'illustrative' | null
  tokens: StockToken[]
}

export type ChainKey = 'arc' | 'base' | 'arbitrum'

export interface ChainSetup {
  key: ChainKey
  /** Short name shown in the UI switcher */
  label: string
  /** EVM chain id */
  id: number
  /** Circle CCTP domain, used by the bridge */
  cctpDomain: number
  /** Official USDC token on this chain (6 decimals) */
  usdc: `0x${string}`
  /** The SplitFactory deployed on this chain. Each chain has its own independent splits. */
  factory: { address: `0x${string}`; abi: typeof SPLIT_ABI }
  /**
   * StrPoints wraps the factory's deposit/distribute so STR points are only awarded for real,
   * successful calls. It also holds daily check-ins, the leaderboard data and the bridge.
   */
  points: { address: `0x${string}`; abi: typeof POINTS_ABI }
  /** On-chain split names (set by each split's creator). Read from the blockchain, never from browser storage. */
  names: { address: `0x${string}`; abi: typeof NAMES_ABI }
  /** On-chain recipient names/tags (set by each split's creator). */
  labels?: { address: `0x${string}`; abi: typeof LABELS_ABI }
  /** Stock Treasury. Only the Base setup has one. */
  stock?: StockSetup
}

const ZERO = '0x0000000000000000000000000000000000000000'

/** Display names, in switcher order. */
const LABELS: Record<ChainKey, string> = { arc: 'Arc', base: 'Base', arbitrum: 'Arbitrum' }
const ALL_KEYS: ChainKey[] = ['arc', 'base', 'arbitrum']
/** Chains that stay switched off until their four contract addresses are filled in src/network.ts. */
const OPTIONAL_KEYS: ChainKey[] = ['arbitrum']
const FIELDS = ['factory', 'points', 'names', 'labels'] as const

// The mainnet version of src/network.ts may list fewer chains, so read it as a partial map.
const NET: Partial<Record<ChainKey, ChainDeployment>> = NETWORK

// A required chain (Arc, Base) with an unset address, or any chain with only some addresses set, stops the
// app at startup rather than sending funds to the zero address. An optional chain with all four unset is
// simply left out.
const problems: string[] = []
const enabled: ChainKey[] = []
const pending: ChainKey[] = []
for (const key of ALL_KEYS) {
  const dep = NET[key]
  if (!dep) continue
  const missing = FIELDS.filter(f => dep[f].toLowerCase() === ZERO)
  if (missing.length === 0) enabled.push(key)
  else if (OPTIONAL_KEYS.includes(key) && missing.length === FIELDS.length) pending.push(key)
  else problems.push(...missing.map(f => `${key}.${f}`))
}
if (problems.length > 0) {
  throw new Error(`src/network.ts is missing deployed contract addresses: ${problems.join(', ')}`)
}

function setup(key: ChainKey): ChainSetup {
  const n = NET[key] as ChainDeployment
  // Read through a local shape so the mainnet network.ts (which has no stock entry) still type-checks.
  const stock = (n as { stock?: { router: `0x${string}`; treasury: `0x${string}`; priceBasis?: 'illustrative'; tokens: StockToken[] } }).stock
  return {
    key,
    label: LABELS[key],
    id: n.id,
    cctpDomain: n.cctpDomain,
    usdc: n.usdc,
    factory: { address: n.factory, abi: SPLIT_ABI },
    points: { address: n.points, abi: POINTS_ABI },
    names: { address: n.names, abi: NAMES_ABI },
    labels: { address: n.labels, abi: LABELS_ABI },
    // Hidden until the Stock Treasury is configured: no router AND no treasury yet means nothing to show.
    stock: stock && !(stock.router.toLowerCase() === ZERO && stock.treasury.toLowerCase() === ZERO)
      ? {
          router: stock.router.toLowerCase() === ZERO ? null : { address: stock.router, abi: ROUTER_ABI },
          treasury: stock.treasury,
          priceBasis: stock.priceBasis ?? null,
          tokens: stock.tokens,
        }
      : undefined,
  }
}

/** Setup for every switched-on chain. Index it only with a key from CHAIN_KEYS (Arc and Base are always present). */
export const CHAINS = Object.fromEntries(enabled.map(k => [k, setup(k)])) as Record<ChainKey, ChainSetup>

/** Chains that are live in this build, in switcher order. */
export const CHAIN_KEYS: ChainKey[] = enabled

/** Chains configured in src/network.ts but not deployed yet (shown as "soon" or hidden by the UI). */
export const PENDING_CHAIN_KEYS: ChainKey[] = pending

/** Display name for any chain key, including ones that are not live yet. */
export const chainLabel = (key: ChainKey): string => LABELS[key]
