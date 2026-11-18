/**
 * Designated icon for each tokenized stock: a rounded tile in the company's brand colour with a simple symbol.
 * These are symbolic marks (not the official company logos). Unknown tickers fall back to a neutral gold tile.
 */
import type { ReactNode } from 'react'
import { Apple, Cpu, Infinity as InfinityIcon, Landmark } from 'lucide-react'

interface Brand { color: string; glyph: (size: number) => ReactNode }

const BRANDS: Record<string, Brand> = {
  // NVIDIA: chip
  NVDAc: { color: '#76B900', glyph: s => <Cpu width={s} height={s} strokeWidth={2} /> },
  // Apple
  AAPLc: { color: '#E8E8ED', glyph: s => <Apple width={s} height={s} strokeWidth={2} /> },
  // Meta: infinity loop
  METAc: { color: '#0A84FF', glyph: s => <InfinityIcon width={s} height={s} strokeWidth={2.4} /> },
  // Alphabet / Google: bold G
  GOOGLc: {
    color: '#4285F4',
    glyph: s => <span className="display font-extrabold leading-none" style={{ fontSize: s * 1.05 }}>G</span>,
  },
  // Tesla: T
  TSLAc: {
    color: '#E31937',
    glyph: s => (
      <svg width={s} height={s} viewBox="0 0 24 24" fill="currentColor" aria-hidden>
        <path d="M3.5 4.5h17v3.4h-6.6V20h-3.8V7.9H3.5z" />
      </svg>
    ),
  },
}

export function StockIcon({ symbol, size = 40 }: { symbol: string; size?: number }) {
  const brand = BRANDS[symbol]
  const color = brand?.color ?? '#F5C842'
  const inner = Math.round(size * 0.5)
  return (
    <span
      className="flex shrink-0 items-center justify-center"
      title={symbol}
      style={{
        width: size,
        height: size,
        borderRadius: Math.round(size * 0.3),
        color,
        background: `${color}22`,
        boxShadow: `inset 0 0 0 1px ${color}55`,
      }}
    >
      {brand ? brand.glyph(inner) : <Landmark width={inner} height={inner} strokeWidth={2} />}
    </span>
  )
}
