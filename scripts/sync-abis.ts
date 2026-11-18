/**
 * Copies the ABIs of the app's contracts from Foundry's build output into src/abi/*.json.
 * The app imports these committed files (contracts/out is git-ignored), so run this after
 * changing a contract:   forge build && bun run abi:sync
 */
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'

const CONTRACTS = ['SplitFactory', 'StrPoints', 'SplitNames', 'RecipientLabels']
/** Base-only extras: synced when their contract is part of the project, skipped otherwise. */
const OPTIONAL = ['FeeRouter']

mkdirSync('src/abi', { recursive: true })
for (const name of [...CONTRACTS, ...OPTIONAL]) {
  const path = `contracts/out/${name}.sol/${name}.json`
  if (OPTIONAL.includes(name) && !existsSync(path)) {
    console.log(`skipped ${name} (no build output; fine if this project does not include it)`)
    continue
  }
  const artifact = JSON.parse(readFileSync(`contracts/out/${name}.sol/${name}.json`, 'utf8')) as { abi: unknown }
  writeFileSync(`src/abi/${name}.json`, JSON.stringify({ abi: artifact.abi }, null, 2) + '\n')
  console.log(`src/abi/${name}.json`)
}
