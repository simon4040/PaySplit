/**
 * Runs automatically before `bun run build` (see "prebuild" in package.json). Stops the build if
 * src/network.ts is not the mainnet file or is only half filled in, so a half-configured app can never be published.
 *
 *  - Arc and Base: all four contract addresses must be set.
 *  - Arbitrum One (optional): all four set, or all four still the zero placeholder (= switched off). Some set = stop.
 *  - Base Stock Treasury (optional): router and treasury both set, or both still zero (= hidden). One set = stop.
 */
import { IS_MAINNET, NETWORK } from '../src/network'

const ZERO = '0x0000000000000000000000000000000000000000'
const isAddress = (v: string) => /^0x[0-9a-fA-F]{40}$/.test(v)
const isZero = (v: string) => v.toLowerCase() === ZERO
const problems: string[] = []
const FIELDS = ['factory', 'points', 'names', 'labels'] as const

if (!IS_MAINNET) problems.push('src/network.ts is not the mainnet version (IS_MAINNET is false)')
if (NETWORK.arc.id !== 5042) problems.push(`Arc chain id should be 5042, found ${NETWORK.arc.id}`)
if (NETWORK.base.id !== 8453) problems.push(`Base chain id should be 8453, found ${NETWORK.base.id}`)

for (const chain of ['arc', 'base'] as const) {
  for (const field of FIELDS) {
    const value = NETWORK[chain][field]
    if (!isAddress(value)) problems.push(`${chain}.${field} is not a valid address: ${value}`)
    else if (isZero(value)) problems.push(`${chain}.${field} is still the zero-address placeholder`)
  }
}

let arbitrumState = 'not in the file'
const arb = NETWORK.arbitrum
if (arb) {
  if (arb.id !== 42161) problems.push(`Arbitrum One chain id should be 42161, found ${arb.id}`)
  for (const field of FIELDS) if (!isAddress(arb[field])) problems.push(`arbitrum.${field} is not a valid address: ${arb[field]}`)
  const unset = FIELDS.filter(f => isZero(arb[f]))
  if (unset.length === 0) arbitrumState = 'live'
  else if (unset.length === FIELDS.length) arbitrumState = 'switched off (all four addresses are still the placeholder)'
  else problems.push(`arbitrum is half filled in, still missing: ${unset.join(', ')}`)
}

let stockState = 'not in the file'
const stock = NETWORK.base.stock
if (stock) {
  if (!isAddress(stock.router)) problems.push(`base.stock.router is not a valid address: ${stock.router}`)
  if (!isAddress(stock.treasury)) problems.push(`base.stock.treasury is not a valid address: ${stock.treasury}`)
  const routerSet = !isZero(stock.router)
  const treasurySet = !isZero(stock.treasury)
  if (routerSet && treasurySet) stockState = 'live'
  else if (!routerSet && !treasurySet) stockState = 'hidden (router and treasury still the placeholder)'
  else problems.push('base.stock needs BOTH router and treasury (or neither)')
  for (const t of stock.tokens) if (!isAddress(t.address)) problems.push(`base.stock token ${t.symbol} is not a valid address: ${t.address}`)
  if (stock.priceBasis === 'illustrative') problems.push("base.stock.priceBasis is 'illustrative': that is for test tokens only, remove it on mainnet")
}

if (problems.length > 0) {
  console.error('\nMainnet configuration is incomplete:\n')
  for (const p of problems) console.error(`  - ${p}`)
  console.error('\nFill in src/network.ts (see README, "Mainnet deployment guide"), then build again.\n')
  process.exit(1)
}
console.log('Mainnet configuration OK.')
console.log('  Arc and Base: all 8 contract addresses are set.')
console.log(`  Arbitrum One: ${arbitrumState}.`)
console.log(`  Base Stock Treasury: ${stockState}.`)
