import { NetworkArc, NetworkArbitrumSepolia, NetworkBase } from '@web3icons/react'
import type { ChainKey } from '@/contract'

const LOGOS = { arc: NetworkArc, base: NetworkBase, arbitrum: NetworkArbitrumSepolia } as const

/** Official network logos (vector, so they stay sharp at any pixel density). */
export function ChainLogo({ chainKey, size = 20, ring }: { chainKey: ChainKey; size?: number; ring?: string }) {
  const Logo = LOGOS[chainKey]
  return (
    <span
      aria-hidden
      className="flex shrink-0 items-center justify-center overflow-hidden rounded-md"
      style={{ width: size, height: size, boxShadow: ring ?? '0 0 0 1px rgba(255,255,255,0.14)' }}
    >
      <Logo variant="background" size={size} />
    </span>
  )
}
