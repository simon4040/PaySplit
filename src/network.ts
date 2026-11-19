/**
 * MAINNET deployment: every chain id, token address, CCTP domain and contract address the app uses.
 * Nothing else in the app hardcodes a chain or an address. This is the ONE file you edit after deploying.
 *
 *   Arc Mainnet    live      (nothing to do)
 *   Base Mainnet   live      (nothing to do, until you add the optional Stock Treasury at the bottom)
 *   Arbitrum One   NEW       paste the 4 addresses after you deploy them (README, step 3)
 *
 * A network with all four addresses left as ZERO_ADDRESS stays switched off and is hidden in the app.
 * A network with only SOME addresses filled in stops the app at start-up, so a half-finished setup is never published.
 */

export const IS_MAINNET = true

/** Circle's CCTP status + fee API (mainnet). */
export const IRIS_API = 'https://iris-api.circle.com'

/** A tokenized stock the Stock Treasury page shows (read with plain ERC-20 calls; decimals are read from the token). */
export interface StockToken {
  symbol: string
  name: string
  address: `0x${string}`
  /** Optional USD price per token. Leave it out on mainnet: real prices need a live price source. */
  usdPrice?: number
}

/** Base-only Stock Treasury: the fee router, the wallet that holds the stock share, and the stocks to show. */
export interface StockConfig {
  /** FeeRouter. ZERO_ADDRESS = not deployed yet. */
  router: `0x${string}`
  /** The stock treasury wallet. The page reads the router's own setting once the router exists; this is the fallback. */
  treasury: `0x${string}`
  /** Only for test tokens: shows dollar values at placeholder prices. Leave unset on mainnet. */
  priceBasis?: 'illustrative'
  tokens: StockToken[]
}

export interface ChainDeployment {
  /** EVM chain id. */
  id: number
  /** Official USDC token (6 decimals). */
  usdc: `0x${string}`
  /** Circle CCTP domain of this chain. */
  cctpDomain: number
  /** SplitFactory: splits, balances, protocol fee. */
  factory: `0x${string}`
  /** StrPoints: STR points, daily check-in, leaderboard, CCTP bridge. */
  points: `0x${string}`
  /** SplitNames: on-chain split names. */
  names: `0x${string}`
  /** RecipientLabels: on-chain recipient names/tags. */
  labels: `0x${string}`
  /** Base only: the Stock Treasury (fee router + tokens). */
  stock?: StockConfig
}

export const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

export const NETWORK: Record<'arc' | 'base', ChainDeployment> & Partial<Record<'arbitrum', ChainDeployment>> = {
  // ---------------------------------------------------------------- Arc Mainnet (live)
  arc: {
    id: 5042,
    usdc: '0x3600000000000000000000000000000000000000',
    cctpDomain: 26,
    factory: '0x5A3EDbcC6406D99dE36ee159B56C6a5Ceb22843A',
    points: '0xe86fD18d14e8104E6108894bA34887737d75e83f',
    names: '0x87A180c552c220Ad592e144Ad69980dC08Ac8204',
    labels: '0x99dCa7934A1d8ad4FB335c92FF078d14260285dc',
  },

  // ---------------------------------------------------------------- Base Mainnet (live)
  base: {
    id: 8453,
    usdc: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
    cctpDomain: 6,
    factory: '0x9336ef11392Db07873cca919EeD8A4C6Cc1bB881',
    points: '0x5Ea945f5491C73978cce56924c4dc92b3b1c3A38',
    names: '0x06e879972f9b24FB258100E9B3A9FeA060Df77D9',
    labels: '0x948787C73cF74Fa25800b57fcbDCa95a516187f2',

    // Optional Stock Treasury (Fee Router). While `router` AND `treasury` are both ZERO_ADDRESS the Stocks tab stays hidden.
    // After you deploy the router (README, step 4): paste its address as `router` and your stock treasury wallet as `treasury`.
    // The five tokens below are the real Coinbase tokenized stocks on Base Mainnet (8 decimals, symbol and name confirmed on-chain).
    stock: {
      router: '0xcA562447C63e8FE4bA21fc8D0ae8229838095c86',
      treasury: '0xe10abbc8c203a70a8aff5897385da9245b49ef59',
      tokens: [
        { symbol: 'NVDAc', name: 'NVIDIA', address: '0xb20000000000000000000078ee7ce2fE4908108C' },
        { symbol: 'AAPLc', name: 'Apple', address: '0xb200000000000000000000C2e324d24d7eEcd1fb' },
        { symbol: 'METAc', name: 'Meta', address: '0xb2000000000000000000008bC8786B856E61707C' },
        { symbol: 'GOOGLc', name: 'Alphabet', address: '0xb2000000000000000000002D0BA3164cc74f58B7' },
        { symbol: 'TSLAc', name: 'Tesla', address: '0xb2000000000000000000001e800a7f5189430cD0' },
      ],
    },
  },

  // ---------------------------------------------------------------- Arbitrum One (new: deploy, then paste the 4 addresses)
  arbitrum: {
    id: 42161,
    usdc: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
    cctpDomain: 3,
    factory: '0x9336ef11392Db07873cca919EeD8A4C6Cc1bB881', // SplitFactory
    points: '0x5ea945f5491c73978cce56924c4dc92b3b1c3a38', // StrPoints
    names: '0x06e879972f9b24FB258100E9B3A9FeA060Df77D9', // SplitNames
    labels: '0x948787C73cF74Fa25800b57fcbDCa95a516187f2', // RecipientLabels
  },
}
