import { useWriteContract as useWagmiWriteContract } from 'wagmi'
import { DATA_SUFFIX } from '@/attribution'

type Write = ReturnType<typeof useWagmiWriteContract>
type Loose = (variables: object, options?: unknown) => unknown

/** Adds the ERC-8021 attribution suffix (if any) to a contract write. Pure, so it can be tested on its own. */
export function withAttribution<T extends object>(variables: T, suffix: `0x${string}` | undefined = DATA_SUFFIX): T {
  return (suffix ? { ...variables, dataSuffix: suffix } : variables)
}

/**
 * Drop-in replacement for wagmi's `useWriteContract` that attaches the Builder Code attribution to every
 * transaction. Use this everywhere the app sends a contract write, so attribution can never be forgotten.
 * Types stay exactly wagmi's: only the runtime call is intercepted.
 */
export function useWriteContract(): Write {
  const w = useWagmiWriteContract()
  const writeContract = ((variables: object, options?: unknown) => (w.writeContract as Loose)(withAttribution(variables), options)) as unknown as Write['writeContract']
  const writeContractAsync = ((variables: object, options?: unknown) => (w.writeContractAsync as Loose)(withAttribution(variables), options)) as unknown as Write['writeContractAsync']
  return { ...w, writeContract, writeContractAsync }
}
