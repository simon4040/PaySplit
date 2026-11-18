/**
 * Where the selected network can bridge to, read from its StrPoints contract. Also reports whether the
 * way back works, so the page can enable or disable the "reverse" button.
 */
import { useReadContract } from 'wagmi'
import { CHAINS, type ChainSetup } from '@/contract'
import { useChain } from '@/hooks/useChain'
import { destinationFor, routeOptions, type RouteOption } from '@/routes'

export interface BridgeRoute {
  loading: boolean
  /** The destination network, or null while loading / when this network has no usable route. */
  dest: ChainSetup | null
  options: RouteOption[]
  /** True when the destination can bridge straight back to the selected network. */
  reverseSupported: boolean
}

export function useBridgeRoute(): BridgeRoute {
  const chain = useChain()
  const forward = useReadContract({
    address: chain.points.address, abi: chain.points.abi, functionName: 'destinationDomain',
    chainId: chain.id, query: { staleTime: Infinity },
  })
  const domain = forward.data !== undefined ? Number(forward.data) : undefined
  const destKey = destinationFor(domain, chain.key)
  const dest = destKey ? CHAINS[destKey] : null

  const back = useReadContract({
    address: dest?.points.address, abi: (dest ?? chain).points.abi, functionName: 'destinationDomain',
    chainId: dest?.id, query: { enabled: !!dest, staleTime: Infinity },
  })

  return {
    loading: forward.isLoading,
    dest,
    options: routeOptions(chain.key, domain),
    reverseSupported: dest !== null && back.data !== undefined && Number(back.data) === chain.cctpDomain,
  }
}
