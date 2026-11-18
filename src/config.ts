/**
 * wagmi configuration (mainnet): Arc, Base and Arbitrum One. Ethereum mainnet is only there for ENS names.
 * Built with Arc Studio, https://studio.arc.io
 */

import { http, createConfig } from 'wagmi'
import { mainnet, base, arc, arbitrum } from 'wagmi/chains'
import { injected } from 'wagmi/connectors'
import { registerChain } from './tracing'

// Pre-register chain RPC URLs so trace events show correct chain names immediately
registerChain(arc.id, arc.rpcUrls.default.http[0])
registerChain(base.id, base.rpcUrls.default.http[0])
registerChain(arbitrum.id, arbitrum.rpcUrls.default.http[0])

export const config = createConfig({
  chains: [arc, base, arbitrum, mainnet], // mainnet needed for ENS resolution
  connectors: [injected()],
  transports: {
    [arc.id]: http(),
    [base.id]: http(),
    [arbitrum.id]: http(),
    [mainnet.id]: http(), // ENS resolution uses mainnet
  },
})
