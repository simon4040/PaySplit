/**
 * Rewards tab: one place for your STR points and the global leaderboard, with a simple two-way switch.
 */
import { useState } from 'react'
import { PointsPage } from '@/components/PointsPage'
import { LeaderboardPage } from '@/components/LeaderboardPage'

type View = 'points' | 'leaderboard'

const VIEWS: { key: View; label: string }[] = [
  { key: 'points', label: 'My points' },
  { key: 'leaderboard', label: 'Leaderboard' },
]

export function RewardsPage() {
  const [view, setView] = useState<View>('points')
  return (
    <div className="space-y-4">
      <div
        role="tablist"
        aria-label="Rewards"
        className="mx-auto flex w-full gap-1 rounded-2xl p-1"
        style={{ background: 'rgba(255,255,255,0.04)', boxShadow: 'inset 0 0 0 1px rgba(255,255,255,0.07)' }}
      >
        {VIEWS.map(v => {
          const active = view === v.key
          return (
            <button
              key={v.key}
              role="tab"
              aria-selected={active}
              onClick={() => setView(v.key)}
              className="flex-1 rounded-xl py-2.5 text-sm font-semibold transition-all active:scale-[0.99]"
              style={{
                background: active ? 'var(--accent)' : 'transparent',
                color: active ? '#0c0c0c' : 'var(--muted)',
                boxShadow: active ? '0 2px 16px rgba(245,200,66,0.22)' : 'none',
              }}
            >
              {v.label}
            </button>
          )
        })}
      </div>
      {view === 'points' ? <PointsPage /> : <LeaderboardPage />}
    </div>
  )
}
