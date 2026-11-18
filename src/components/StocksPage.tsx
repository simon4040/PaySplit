/**
 * Stocks tab (Base only): what the stock treasury holds and how protocol fees reach it.
 * Calm by default: headline numbers, fees waiting, holdings. Technical details are folded away.
 */
import { useEffect, useRef, useState } from 'react'
import { useAccount, useSwitchChain, useWaitForTransactionReceipt } from 'wagmi'
import { useWriteContract } from '@/hooks/useWrite'
import { useQueryClient } from '@tanstack/react-query'
import { ChevronDown, ChevronRight, ExternalLink, Info, Landmark, Loader2, Link2 } from 'lucide-react'
import { formatUnits } from 'viem'
import { toast } from 'sonner'
import { useChain } from '@/hooks/useChain'
import { useStockTreasury } from '@/hooks/useStockTreasury'
import { useFeeConfig } from '@/hooks/useFeeConfig'
import { explorerAddressUrl } from '@/explorer'
import { bpsToPercent, formatAddress, parseOnchainError } from '@/utils'
import { StockIcon } from '@/components/StockIcon'

const card: React.CSSProperties = {
  background: 'rgba(255,255,255,0.035)',
  border: '1px solid rgba(245,200,66,0.12)',
  boxShadow: '0 4px 24px rgba(0,0,0,0.24)',
}
const inner: React.CSSProperties = { background: 'rgba(0,0,0,0.26)', boxShadow: 'inset 0 0 0 1px rgba(255,255,255,0.06)' }
const label = 'text-[0.65rem] font-semibold uppercase tracking-widest'

/** Token amount with up to 4 decimals, trailing zeros trimmed (keeps at least 2). */
function fmt(raw: bigint, decimals = 6): string {
  const [whole, frac = ''] = formatUnits(raw, decimals).split('.')
  return `${Number(whole).toLocaleString('en-US')}.${frac.slice(0, 4).replace(/0+$/, '').padEnd(2, '0')}`
}

/** A write whose confirmation is announced once. */
function useAction(onDone: () => void) {
  const w = useWriteContract()
  const r = useWaitForTransactionReceipt({ hash: w.data, query: { enabled: !!w.data } })
  const notified = useRef<string | null>(null)
  const { reset } = w
  useEffect(() => {
    if (!r.isSuccess || !w.data || notified.current === w.data) return
    notified.current = w.data
    onDone()
    reset()
  }, [r.isSuccess, w.data, onDone, reset])
  return { write: w.writeContract, pending: w.isPending, confirming: r.isLoading }
}

const usdFmt = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' })

function Row({ k, children }: { k: string; children: React.ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-4 py-2">
      <span className="text-xs" style={{ color: 'var(--subtle)' }}>{k}</span>
      <span className="min-w-0 text-right text-xs tabular-nums" style={{ color: 'var(--ink-2)' }}>{children}</span>
    </div>
  )
}

function AddressLink({ chainId, address }: { chainId: number; address: string }) {
  const url = explorerAddressUrl(chainId, address)
  if (!url) return <span className="font-mono" title={address} style={{ color: 'var(--ink-2)' }}>{formatAddress(address)}</span>
  return (
    <a href={url} target="_blank" rel="noreferrer" title={address}
       className="inline-flex items-center gap-1 font-mono" style={{ color: 'var(--ink-2)' }}>
      {formatAddress(address)} <ExternalLink className="size-3" />
    </a>
  )
}

/** Slim summary shown on Home (Base only); opens the Stocks tab. */
export function StockSummaryLink({ onOpen }: { onOpen: () => void }) {
  const chain = useChain()
  const { data: snap } = useStockTreasury()
  if (!chain.stock) return null
  const held = (snap?.holdings ?? []).filter(h => h.deployed && (h.balance ?? 0n) > 0n)
  const symbols = (snap?.holdings ?? chain.stock.tokens.map(token => ({ token }))).slice(0, 3).map(h => h.token.symbol)
  return (
    <button
      onClick={onOpen}
      className="flex w-full items-center gap-3 rounded-2xl px-4 py-3 text-left transition-all active:scale-[0.99] hover:bg-white/[0.04]"
      style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(245,200,66,0.10)' }}
    >
      <div className="flex shrink-0 -space-x-2">
        {symbols.map(s => <span key={s} className="rounded-xl ring-2 ring-[#0c0c0c]"><StockIcon symbol={s} size={28} /></span>)}
      </div>
      <div className="min-w-0 flex-1">
        <p className="text-sm font-semibold" style={{ color: 'var(--ink)' }}>Stock Treasury</p>
        <p className="truncate text-xs tabular-nums" style={{ color: 'var(--muted)' }}>
          {snap?.treasuryUsdc != null ? `${fmt(snap.treasuryUsdc)} USDC` : '…'} · {held.length} stock{held.length === 1 ? '' : 's'}
        </p>
      </div>
      <ChevronRight className="size-4 shrink-0" style={{ color: 'var(--subtle)' }} />
    </button>
  )
}

export function StocksPage() {
  const chain = useChain()
  const stock = chain.stock
  const { data: snap, isLoading } = useStockTreasury()
  const { address, isConnected, chainId } = useAccount()
  const { switchChain } = useSwitchChain()
  const queryClient = useQueryClient()
  const fee = useFeeConfig()
  const [details, setDetails] = useState(false)
  const [noteOpen, setNoteOpen] = useState(false)

  const refresh = () => {
    void queryClient.invalidateQueries({ queryKey: ['stock-treasury'] })
    void fee.refetch()
  }
  const send = useAction(() => { toast.success('Fees sent on.'); refresh() })
  const connect = useAction(() => { toast.success('Fee split switched on.'); setTimeout(refresh, 2500) })

  if (!stock) return null

  const router = snap?.router ?? null
  const stockBps = router?.stockFeeBps ?? 0
  const stockPct = bpsToPercent(stockBps)
  const restPct = bpsToPercent(10_000 - stockBps)
  const feePct = snap?.factoryFeeBps != null ? bpsToPercent(snap.factoryFeeBps) : null
  const pending = router?.pendingBalance ?? 0n
  const isWrongChain = isConnected && chainId !== chain.id
  const isOwner = !!address && !!fee.owner && address.toLowerCase() === fee.owner.toLowerCase()
  const canConnect = isOwner && !!router && !!snap && !snap.wired
  const holdings = snap?.holdings ?? stock.tokens.map(token => ({ token, deployed: false, decimals: 18, balance: null as bigint | null }))
  // Dollar values: USDC at 1:1, stocks at the configured (illustrative) price. Display only.
  const illustrative = stock.priceBasis === 'illustrative'
  const usdOf = (h: (typeof holdings)[number]): number | null =>
    h.deployed && h.balance !== null && h.token.usdPrice != null ? Number(formatUnits(h.balance, h.decimals)) * h.token.usdPrice : null
  const priced = holdings.filter(h => usdOf(h) !== null)
  const stocksUsd = priced.reduce((sum, h) => sum + (usdOf(h) ?? 0), 0)
  const usdcUsd = snap?.treasuryUsdc != null ? Number(formatUnits(snap.treasuryUsdc, 6)) : null
  const totalUsd = usdcUsd !== null && priced.length > 0 ? usdcUsd + stocksUsd : null

  const sendFees = () => {
    if (!stock.router) return
    if (isWrongChain) { switchChain({ chainId: chain.id }); return }
    send.write(
      { address: stock.router.address, abi: stock.router.abi, functionName: 'flush', chainId: chain.id },
      { onError: e => toast.error(parseOnchainError(e)) },
    )
  }
  const connectSplit = () => {
    if (!stock.router) return
    if (isWrongChain) { switchChain({ chainId: chain.id }); return }
    connect.write(
      { address: chain.factory.address, abi: chain.factory.abi, functionName: 'setFeeRecipient', args: [stock.router.address], chainId: chain.id },
      { onError: e => toast.error(parseOnchainError(e)) },
    )
  }

  // One plain sentence about where things stand
  const headline = !snap ? 'Loading…'
    : !router ? 'The fee split is not set up on this network yet.'
    : !snap.wired ? 'The fee split is not switched on yet, so fees still go straight to the fee wallet.'
    : !snap.stockActive ? 'The stock share is off right now. All fees go to the fee wallet.'
    : `${stockPct}% of every protocol fee goes to this treasury.`
  const live = !!snap?.wired && !!snap?.stockActive
  const sendBusy = send.pending || send.confirming
  const sendOff = !isConnected || sendBusy || (pending === 0n && !isWrongChain)

  const example = (() => {
    if (!snap || snap.factoryFeeBps == null) return null
    const f = (100_000_000n * BigInt(snap.factoryFeeBps)) / 10_000n
    const toStock = snap.stockActive ? (f * BigInt(stockBps)) / 10_000n : 0n
    return { fee: f, toStock, rest: f - toStock }
  })()

  return (
    <div className="space-y-4">
      {/* Title */}
      <div className="flex items-center gap-2.5 px-1">
        <div className="flex size-9 items-center justify-center rounded-xl" style={{ background: 'rgba(245,200,66,0.10)', border: '1px solid rgba(245,200,66,0.22)', color: 'var(--accent)' }}>
          <Landmark className="size-4.5" />
        </div>
        <h2 className="display text-xl font-bold" style={{ color: 'var(--ink)', letterSpacing: '-0.02em' }}>Stock Treasury</h2>
        <span className="rounded-md px-1.5 py-0.5 text-[0.6rem] font-bold uppercase tracking-wider" style={{ background: 'rgba(255,255,255,0.07)', color: 'var(--muted)' }}>{chain.label}</span>
      </div>

      {/* Headline */}
      <div className="rounded-3xl p-6" style={{
        background: 'linear-gradient(135deg, rgba(245,200,66,0.09) 0%, rgba(255,255,255,0.025) 100%)',
        border: '1px solid rgba(245,200,66,0.20)',
        boxShadow: '0 8px 40px rgba(0,0,0,0.34), inset 0 1px 0 rgba(255,255,255,0.05)',
      }}>
        <p className={label} style={{ color: 'var(--muted)' }}>Treasury holds</p>
        <div className="mt-2 flex items-baseline gap-2">
          <span className="display font-bold tabular-nums" style={{ color: 'var(--ink)', fontSize: 'clamp(2.4rem,10vw,3.2rem)', letterSpacing: '-0.04em', lineHeight: 1 }}>
            {snap?.treasuryUsdc != null ? fmt(snap.treasuryUsdc) : isLoading ? '…' : '—'}
          </span>
          <span className="text-lg font-medium" style={{ color: 'var(--accent)' }}>USDC</span>
        </div>
        {totalUsd !== null && (
          <p className="mt-3 text-sm tabular-nums" style={{ color: 'var(--ink-2)' }}>
            Total value <span className="display font-bold" style={{ color: 'var(--ink)' }}>≈ {usdFmt.format(totalUsd)}</span>
            <span className="ml-1.5 text-xs" style={{ color: 'var(--subtle)' }}>
              ({usdFmt.format(usdcUsd ?? 0)} USDC + {usdFmt.format(stocksUsd)} stocks{illustrative ? ', illustrative prices' : ''})
            </span>
          </p>
        )}
        <div className="mt-4 flex -space-x-2">
          {holdings.map(h => <span key={h.token.symbol} className="rounded-xl ring-2 ring-[#16130a]"><StockIcon symbol={h.token.symbol} size={32} /></span>)}
        </div>
        <p className="mt-4 text-sm leading-relaxed" style={{ color: live ? 'var(--ink-2)' : 'var(--muted)' }}>{headline}</p>
        {canConnect && (
          <button
            onClick={connectSplit}
            disabled={connect.pending || connect.confirming}
            className="mt-4 flex w-full items-center justify-center gap-2 rounded-2xl py-3 text-sm font-semibold transition-all active:scale-[0.99] disabled:cursor-not-allowed"
            style={{ background: 'var(--accent)', color: '#0c0c0c', boxShadow: '0 4px 24px rgba(245,200,66,0.24)' }}
          >
            {connect.pending || connect.confirming
              ? <><Loader2 className="size-4 animate-spin" />{connect.pending ? 'Confirm in wallet…' : 'Switching on…'}</>
              : isWrongChain ? `Switch to ${chain.label}` : <><Link2 className="size-4" />Switch on the fee split</>}
          </button>
        )}
      </div>

      {/* Disclosure: the headline is always visible; the detail folds. Nothing here is hardcoded to one network or wallet. */}
      <div className="rounded-3xl p-5" role="note" style={{ background: 'rgba(245,200,66,0.045)', border: '1px solid rgba(245,200,66,0.16)' }}>
        <div className="flex items-start gap-3">
          <div className="flex size-8 shrink-0 items-center justify-center rounded-xl" style={{ background: 'rgba(245,200,66,0.12)', color: 'var(--accent)' }}>
            <Info className="size-4" />
          </div>
          <div className="min-w-0 flex-1">
            <p className="text-sm font-semibold" style={{ color: 'var(--ink)' }}>Stocks are not bought automatically</p>
            <p className="mt-0.5 text-xs leading-relaxed" style={{ color: 'var(--muted)' }}>
              Fees reach the treasury as USDC. The holdings below are whatever the treasury wallet holds.
            </p>
          </div>
          <button
            onClick={() => setNoteOpen(o => !o)}
            aria-expanded={noteOpen}
            className="flex shrink-0 items-center gap-1 rounded-full px-2.5 py-1 text-[0.7rem] font-semibold transition-colors hover:bg-white/[0.05]"
            style={{ color: 'var(--ink-2)' }}
          >
            {noteOpen ? 'Less' : 'More'}
            <ChevronDown className="size-3.5 transition-transform" style={{ transform: noteOpen ? 'rotate(180deg)' : 'none' }} />
          </button>
        </div>
        {noteOpen && (
          <div className="mt-3 space-y-2 border-t pt-3 pl-11 text-xs leading-relaxed" style={{ borderColor: 'rgba(255,255,255,0.06)', color: 'var(--muted)' }}>
            <p>
              Treasury wallet: <AddressLink chainId={chain.id} address={snap?.treasury ?? stock.treasury} />
              {snap?.router ? '' : ' (planned)'}. This app and the fee split contract cannot move it.
            </p>
            {illustrative && <p>These are test stocks with no market price, so their dollar values use illustrative placeholder prices.</p>}
          </div>
        )}
      </div>

      {/* Fees waiting */}
      {router && (
        <div className="rounded-3xl p-5" style={card}>
          <div className="flex items-center justify-between gap-4">
            <div className="min-w-0">
              <p className={label} style={{ color: 'var(--subtle)' }}>Fees waiting</p>
              <p className="display mt-1 text-2xl font-bold tabular-nums" style={{ color: 'var(--ink)' }}>
                {fmt(pending)} <span className="text-sm font-medium" style={{ color: 'var(--muted)' }}>USDC</span>
              </p>
            </div>
            <button
              onClick={sendFees}
              disabled={sendOff}
              className="shrink-0 rounded-xl px-4 py-2.5 text-sm font-semibold transition-all active:scale-[0.98] disabled:cursor-not-allowed"
              style={{ background: sendOff ? 'rgba(255,255,255,0.06)' : 'var(--accent)', color: sendOff ? 'var(--muted)' : '#0c0c0c' }}
            >
              {sendBusy ? <span className="flex items-center gap-1.5"><Loader2 className="size-3.5 animate-spin" />{send.pending ? 'Confirm…' : 'Sending…'}</span>
                : !isConnected ? 'Connect wallet'
                : isWrongChain ? `Switch to ${chain.label}`
                : pending === 0n ? 'Nothing waiting' : 'Send to treasury'}
            </button>
          </div>
          <p className="mt-3 text-xs leading-relaxed" style={{ color: 'var(--subtle)' }}>
            Anyone can send waiting fees on. {stockPct}% goes to the treasury and {restPct}% to the fee wallet.
          </p>
        </div>
      )}

      {/* Holdings */}
      <div className="rounded-3xl p-5" style={card}>
        <p className={`${label} mb-3`} style={{ color: 'var(--subtle)' }}>Stock holdings</p>
        <ul className="space-y-2">
          {holdings.map(h => (
            <li key={h.token.symbol} className="flex items-center gap-3 rounded-2xl px-3.5 py-3" style={inner}>
              <StockIcon symbol={h.token.symbol} size={40} />
              <div className="min-w-0 flex-1">
                <p className="display text-sm font-bold" style={{ color: 'var(--ink)' }}>{h.token.symbol}</p>
                <p className="truncate text-xs" style={{ color: 'var(--subtle)' }}>{h.token.name}</p>
              </div>
              <div className="text-right">
                {h.deployed && h.balance !== null ? (
                  <>
                    <p className="display text-base font-bold tabular-nums" style={{ color: h.balance > 0n ? 'var(--accent)' : 'var(--muted)' }}>
                      {usdOf(h) !== null ? usdFmt.format(usdOf(h) ?? 0) : `${fmt(h.balance, h.decimals)} ${h.token.symbol}`}
                    </p>
                    {usdOf(h) !== null && (
                      <p className="text-xs tabular-nums" style={{ color: 'var(--subtle)' }}>
                        {fmt(h.balance, h.decimals)} {h.token.symbol}{h.token.usdPrice != null ? ` · @ ${usdFmt.format(h.token.usdPrice)}` : ''}
                      </p>
                    )}
                  </>
                ) : (
                  <p className="text-sm" style={{ color: 'var(--subtle)' }}>—</p>
                )}
              </div>
            </li>
          ))}
        </ul>
        {illustrative && <p className="mt-3 text-xs" style={{ color: 'var(--subtle)' }}>Test tokens standing in for real tokenized stocks. Dollar values are illustrative, not market prices.</p>}
      </div>

      {/* Details, folded */}
      <div className="overflow-hidden rounded-3xl" style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(245,200,66,0.10)' }}>
        <button
          onClick={() => setDetails(d => !d)}
          aria-expanded={details}
          className="flex w-full items-center justify-between px-5 py-4 text-left transition-colors hover:bg-white/[0.03]"
        >
          <span className={label} style={{ color: 'var(--muted)', letterSpacing: '0.09em' }}>Details</span>
          <ChevronDown className="size-4 transition-transform" style={{ color: 'var(--muted)', transform: details ? 'rotate(180deg)' : 'none' }} />
        </button>
        {details && snap && (
          <div className="divide-y px-5 pb-4" style={{ borderColor: 'rgba(255,255,255,0.06)' }}>
            <Row k="Protocol fee">{feePct ? `${feePct}% of every deposit and bridge` : '…'}</Row>
            <Row k="Stock treasury wallet"><AddressLink chainId={chain.id} address={snap.treasury} /></Row>
            {router && stock.router && <Row k="Fee split contract"><AddressLink chainId={chain.id} address={stock.router.address} /></Row>}
            {router && <Row k="Fee wallet (the rest)"><AddressLink chainId={chain.id} address={router.feeRecipient} /></Row>}
            {router && <Row k="Sent to treasury so far">{fmt(router.totalToStock)} USDC</Row>}
            {router && <Row k="Sent to fee wallet so far">{fmt(router.totalToFeeRecipient)} USDC</Row>}
            {example && router && (
              <Row k="Example, 100 USDC deposit">{fmt(example.fee)} fee: {fmt(example.toStock)} to treasury, {fmt(example.rest)} to fee wallet</Row>
            )}
            <Row k="Status">{live ? 'Live' : router ? (snap.wired ? 'Stock share off' : 'Not switched on') : 'Not set up'}</Row>
          </div>
        )}
      </div>
    </div>
  )
}
