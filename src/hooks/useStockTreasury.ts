/**
 * Stock Treasury data for the selected network. Only Base has a `stock` setup, so on every other network
 * the query stays off and `enabled` is false.
 */
import { usePublicClient } from 'wagmi'
import { useQuery } from '@tanstack/react-query'
import type { PublicClient } from 'viem'
import { useChain } from '@/hooks/useChain'
import { readStockSnapshot } from '@/stock'

export function useStockTreasury() {
  const chain = useChain()
  const client = usePublicClient({ chainId: chain.id })
  const stock = chain.stock

  return useQuery({
    queryKey: ['stock-treasury', chain.id, stock?.router?.address ?? 'no-router', stock?.treasury ?? 'none'],
    queryFn: () => readStockSnapshot(client as PublicClient, chain),
    enabled: !!stock && !!client,
    refetchInterval: 10_000,
  })
}
