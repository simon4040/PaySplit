import { useState, type ReactNode } from 'react'
import { CHAINS, CHAIN_KEYS, type ChainKey } from '@/contract'
import { ChainContext } from '@/hooks/useChain'

const STORAGE_KEY = 'selected-chain'

function readInitial(): ChainKey {
  try {
    const v = localStorage.getItem(STORAGE_KEY)
    // Only a network that is live in this build can be restored (a saved choice may point at one that is not).
    if (v && (CHAIN_KEYS as string[]).includes(v)) return v as ChainKey
  } catch { /* storage unavailable */ }
  return 'arc'
}

export function ChainProvider({ children }: { children: ReactNode }) {
  const [key, setKey] = useState<ChainKey>(readInitial)

  const setChainKey = (next: ChainKey) => {
    if (!CHAIN_KEYS.includes(next)) return
    setKey(next)
    try { localStorage.setItem(STORAGE_KEY, next) } catch { /* silent */ }
  }

  return (
    <ChainContext.Provider value={{ chain: CHAINS[key], setChainKey }}>
      {children}
    </ChainContext.Provider>
  )
}
