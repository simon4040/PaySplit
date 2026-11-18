/**
 * PaySplit Protocol logo: a gold "one stream in, two out" mark in a polished tile, and a stacked wordmark
 * ("PaySplit" over a small spaced-out "PROTOCOL"). Compact enough for a mobile header.
 */
const GRAD = 'ps-logo-gold'

const goldText: React.CSSProperties = {
  background: 'linear-gradient(180deg, #FFE9A6 0%, #F5C842 100%)',
  WebkitBackgroundClip: 'text',
  backgroundClip: 'text',
  color: 'transparent',
}

export function LogoMark({ size = 34 }: { size?: number }) {
  const g = `url(#${GRAD})`
  return (
    <span
      className="relative flex shrink-0 items-center justify-center"
      style={{
        width: size,
        height: size,
        borderRadius: Math.round(size * 0.3),
        background: 'linear-gradient(145deg, rgba(245,200,66,0.24) 0%, rgba(245,200,66,0.07) 58%, rgba(255,255,255,0.04) 100%)',
        boxShadow:
          'inset 0 0 0 1px rgba(245,200,66,0.40), inset 0 1px 0 rgba(255,255,255,0.14), 0 4px 18px rgba(245,200,66,0.16)',
      }}
    >
      <svg viewBox="0 0 24 24" width={size * 0.62} height={size * 0.62} fill="none" aria-hidden>
        <defs>
          <linearGradient id={GRAD} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#FFE9A6" />
            <stop offset="1" stopColor="#F5C842" />
          </linearGradient>
        </defs>
        {/* One stream in at the top, split into two at the bottom */}
        <path d="M12 4.6V10" stroke={g} strokeWidth="2.2" strokeLinecap="round" />
        <path d="M12 10c0 3.2-6 3.2-6 7.4" stroke={g} strokeWidth="2.2" strokeLinecap="round" />
        <path d="M12 10c0 3.2 6 3.2 6 7.4" stroke={g} strokeWidth="2.2" strokeLinecap="round" />
        <circle cx="12" cy="3.7" r="1.9" fill={g} />
        <circle cx="6" cy="19" r="1.9" fill={g} />
        <circle cx="18" cy="19" r="1.9" fill={g} />
      </svg>
    </span>
  )
}

export function Logo() {
  return (
    <div className="flex items-center gap-2.5">
      <LogoMark />
      <span className="flex flex-col leading-none">
        <span className="display text-[1.08rem] font-bold" style={{ color: 'var(--ink)', letterSpacing: '-0.025em' }}>
          Pay<span style={goldText}>Split</span>
        </span>
        <span className="mt-1 text-[0.5rem] font-semibold uppercase" style={{ color: 'var(--muted)', letterSpacing: '0.36em' }}>
          Protocol
        </span>
      </span>
    </div>
  )
}
