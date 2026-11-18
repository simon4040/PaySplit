import { CHAINS, CHAIN_KEYS, PENDING_CHAIN_KEYS, chainLabel, type ChainKey } from '@/contract'
import { useChainSwitch } from '@/hooks/useChain'
import { ChainLogo } from '@/components/ChainLogo'

/** Segmented Arc / Base / Arbitrum control. A network whose contracts are not deployed yet shows as "Soon" and cannot be picked. */
export function ChainSwitcher({ onChange }: { onChange?: (key: ChainKey) => void }) {
  const { chain, setChainKey } = useChainSwitch()

  return (
    <div
      role="tablist"
      aria-label="Network"
      className="mx-auto flex w-fit max-w-full flex-wrap items-center justify-center gap-1 rounded-2xl p-1"
      style={{
        background: 'rgba(255,255,255,0.04)',
        border: '1px solid rgba(245,200,66,0.12)',
      }}
    >
      {CHAIN_KEYS.map(key => {
        const active = chain.key === key
        return (
          <button
            key={key}
            role="tab"
            aria-selected={active}
            onClick={() => {
              if (active) return
              setChainKey(key)
              onChange?.(key)
            }}
            className="flex items-center justify-center gap-1.5 rounded-xl px-3 py-2 text-sm font-semibold transition-all active:scale-[0.98] sm:gap-2 sm:px-4"
            style={{
              background: active ? 'var(--accent)' : 'transparent',
              color: active ? '#0c0c0c' : 'var(--muted)',
              boxShadow: active ? '0 2px 16px rgba(245,200,66,0.22)' : 'none',
            }}
          >
            <ChainLogo chainKey={key} ring={active ? '0 0 0 1.5px rgba(12,12,12,0.22)' : undefined} />
            {CHAINS[key].label}
          </button>
        )
      })}
      {PENDING_CHAIN_KEYS.map(key => (
        <button
          key={key}
          role="tab"
          aria-selected={false}
          aria-disabled
          disabled
          title={`${chainLabel(key)} is not available yet`}
          className="flex cursor-not-allowed items-center justify-center gap-1.5 rounded-xl px-3 py-2 text-sm font-semibold sm:gap-2 sm:px-4"
          style={{ background: 'transparent', color: 'var(--subtle)', opacity: 0.6 }}
        >
          <span style={{ opacity: 0.55 }}><ChainLogo chainKey={key} /></span>
          {chainLabel(key)}
          <span
            className="rounded-md px-1.5 py-0.5 text-[0.6rem] font-bold uppercase tracking-wider"
            style={{ background: 'rgba(255,255,255,0.07)', color: 'var(--muted)' }}
          >
            Soon
          </span>
        </button>
      ))}
    </div>
  )
}
