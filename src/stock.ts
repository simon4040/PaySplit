/**
 * Reads everything the Stock Treasury card shows, in two batched calls: the fee router and factory
 * settings first, then the treasury's USDC and stock-token balances. Plain TypeScript (no React) so it
 * can be tested on its own against any RPC.
 */
import { erc20Abi, type Abi, type Address, type PublicClient } from 'viem'
import { ROUTER_ABI, type ChainSetup, type StockToken } from '@/contract'

const ZERO = '0x0000000000000000000000000000000000000000'
const isZero = (a: string) => a.toLowerCase() === ZERO
const same = (a: string, b: string) => a.toLowerCase() === b.toLowerCase()

export interface RouterState {
  owner: Address
  feeRecipient: Address
  stockTreasury: Address
  /** Share of every flushed fee that goes to the stock treasury, in basis points (3000 = 30%). */
  stockFeeBps: number
  /** USDC sitting in the router, waiting to be routed. */
  pendingBalance: bigint
  pendingStock: bigint
  pendingRest: bigint
  /** Lifetime totals already paid out. */
  totalToStock: bigint
  totalToFeeRecipient: bigint
}

export interface Holding {
  token: StockToken
  /** False for a test token that has not been deployed yet. */
  deployed: boolean
  decimals: number
  /** Null when the token is not deployed or the read failed. */
  balance: bigint | null
}

export interface StockSnapshot {
  /** Null until the FeeRouter is deployed. */
  router: RouterState | null
  /** The protocol fee the factory takes on every deposit and bridge. */
  factoryFeeBps: number | null
  factoryFeeRecipient: Address | null
  /** True when the factory pays its fee to the router, so deposit and bridge fees really flow through it. */
  wired: boolean
  /** The wallet that holds the stock share (the router's setting once it exists, otherwise the planned one). */
  treasury: Address
  /** The stock share is switched on: a router exists, has a treasury and a share above 0. */
  stockActive: boolean
  treasuryUsdc: bigint | null
  holdings: Holding[]
}

interface Call { address: Address; abi: Abi; functionName: string; args?: readonly unknown[] }

/** Runs a batch and returns each result, or undefined where a call failed. */
async function batch(client: PublicClient, calls: Call[]): Promise<unknown[]> {
  if (calls.length === 0) return []
  const out = await client.multicall({ contracts: calls, allowFailure: true })
  return out.map(r => (r.status === 'success' ? r.result : undefined))
}

export async function readStockSnapshot(client: PublicClient, chain: ChainSetup): Promise<StockSnapshot> {
  const stock = chain.stock
  if (!stock) throw new Error(`${chain.label} has no Stock Treasury`)
  const router = stock.router?.address ?? null
  const factory = chain.factory.address
  const factoryAbi = chain.factory.abi as Abi
  const routerAbi = ROUTER_ABI as Abi

  // Step 1: settings.
  const calls: Call[] = [
    { address: factory, abi: factoryAbi, functionName: 'feeBps' },
    { address: factory, abi: factoryAbi, functionName: 'feeRecipient' },
  ]
  if (router) {
    for (const fn of ['owner', 'feeRecipient', 'stockTreasury', 'stockFeeBps', 'pending', 'totalRoutedToStock', 'totalRoutedToFeeRecipient']) {
      calls.push({ address: router, abi: routerAbi, functionName: fn })
    }
  }
  const r = await batch(client, calls)
  const factoryFeeBps = r[0] !== undefined ? Number(r[0]) : null
  const factoryFeeRecipient = (r[1] as Address | undefined) ?? null

  let routerState: RouterState | null = null
  if (router && r[2] !== undefined && r[4] !== undefined && r[5] !== undefined && r[6] !== undefined) {
    const pending = (r[6] as readonly [bigint, bigint, bigint] | undefined) ?? [0n, 0n, 0n]
    routerState = {
      owner: r[2] as Address,
      feeRecipient: r[3] as Address,
      stockTreasury: r[4] as Address,
      stockFeeBps: Number(r[5]),
      pendingBalance: pending[0],
      pendingStock: pending[1],
      pendingRest: pending[2],
      totalToStock: (r[7] as bigint | undefined) ?? 0n,
      totalToFeeRecipient: (r[8] as bigint | undefined) ?? 0n,
    }
  }

  const treasury = routerState && !isZero(routerState.stockTreasury) ? routerState.stockTreasury : stock.treasury

  // Step 2: balances held by the treasury.
  const deployedTokens = stock.tokens.filter(t => !isZero(t.address))
  const calls2: Call[] = [{ address: chain.usdc, abi: erc20Abi, functionName: 'balanceOf', args: [treasury] }]
  for (const t of deployedTokens) {
    calls2.push({ address: t.address, abi: erc20Abi, functionName: 'balanceOf', args: [treasury] })
    calls2.push({ address: t.address, abi: erc20Abi, functionName: 'decimals' })
  }
  const b = await batch(client, calls2)
  const byAddress = new Map<string, { balance: bigint | null; decimals: number }>()
  deployedTokens.forEach((t, i) => {
    const bal = b[1 + i * 2] as bigint | undefined
    const dec = b[2 + i * 2] as number | undefined
    byAddress.set(t.address.toLowerCase(), { balance: bal ?? null, decimals: dec !== undefined ? Number(dec) : 18 })
  })

  return {
    router: routerState,
    factoryFeeBps,
    factoryFeeRecipient,
    wired: !!router && !!factoryFeeRecipient && same(factoryFeeRecipient, router),
    treasury,
    stockActive: !!routerState && !isZero(routerState.stockTreasury) && routerState.stockFeeBps > 0,
    treasuryUsdc: (b[0] as bigint | undefined) ?? null,
    holdings: stock.tokens.map(token => {
      const hit = byAddress.get(token.address.toLowerCase())
      return { token, deployed: !isZero(token.address), decimals: hit?.decimals ?? 18, balance: hit?.balance ?? null }
    }),
  }
}
