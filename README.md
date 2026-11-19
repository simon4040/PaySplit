# PaySplit Protocol

Split USDC on Arc, Base & Arbitrum. Anyone can create a named split, assign recipients with percentage
shares, deposit USDC, and trigger a single **Distribute** that pays every recipient proportionally. A small,
adjustable protocol fee is taken on deposits and bridges. Users earn STR points and can bridge USDC between Arc, Base and Arbitrum. 30% of fees collected on Base goes to the stock treasury. 


## What it does

- Create a split with up to 20 recipients whose shares total 100%. Each split has its own USDC balance.
  Anyone can deposit into any split and anyone can distribute it.
- Every split has a required **name**, and recipients can have a **name or tag**. Both are stored on-chain, so they
  show on any device. A split without a name shows as "Split #ID"; a recipient without a tag shows just the address.
- A **protocol fee** (default 0.5%, never above 5%) is taken on each deposit and each bridge and sent to a fee
  recipient. The screen shows the exact fee before you confirm. The contract owner can change the fee and the
  fee recipient from the owner panel.
- Four pages with a bottom navigation bar: **Home**, **Bridge**, **Points**, **Leaderboard**. A network switcher
  (Arc, Base and Arbitrum Sepolia) moves between
  networks, which have separate splits, balances and fee settings.
- **Bridge USDC** with CCTP Fast Transfer. Each network bridges to one fixed destination: Arc to Base, Base to Arc and
  Arbitrum to Base. Routes that are not available are shown disabled with a short note. The page shows the platform
  fee, the network fee, the amount you receive and live progress. One bridge at a time per wallet.
- **STR points** for deposits, distributions and bridges by amount, plus a daily check-in:

  | Amount (USDC) | STR | Daily max once reached |
  |---|---|---|
  | under 1 | 0 | 50 |
  | 1 to 9.99 | +5 | 50 |
  | 10 to 49.99 | +25 | 75 |
  | 50 to 99.99 | +50 | 100 |
  | 100 to 249.99 | +75 | 150 |
  | 250 to 999.99 | +100 | 200 |
  | 1,000 and above | +150 | 600 |

  The daily max (deposits, distributions and bridges combined) starts at 50 and rises to the highest tier reached
  that day. Deposits and bridges count by the amount sent; a distribution counts by the split's balance after the
  fee. Daily check-in is +5, with +25 on the 7th consecutive day (then the streak resets; missing a day also
  resets it). A "day" is a UTC calendar day (resets at 00:00 UTC). The global **Leaderboard** ranks wallets by
  total STR across all live networks, with gold, silver and bronze medals for the top three.
- If a recipient cannot receive USDC (for example a blocklisted address), their share is kept for them to claim
  later. It is never given to anyone else.

## The contracts

Four contracts are deployed on **each** network (eight in total). Deploy `SplitFactory` first; the other three
need its address.

| Contract | File | Purpose | Constructor arguments (in order) |
|---|---|---|---|
| `SplitFactory` | `contracts/SplitFactory.sol` | Splits, balances, protocol fee, owner | `address _usdc`, `address _owner`, `address _feeRecipient`, `uint16 _feeBps` |
| `StrPoints` | `contracts/StrPoints.sol` | STR points, check-in, leaderboard data, CCTP bridge | `address _factory`, `address _usdc`, `uint256 _dayLength`, `address _tokenMessenger`, `uint32 _destinationDomain` |
| `SplitNames` | `contracts/SplitNames.sol` | On-chain split names | `address _factory` |
| `RecipientLabels` | `contracts/RecipientLabels.sol` | On-chain recipient names/tags | `address _factory` |

Notes on the contracts:

- `SplitFactory`: ownership uses a two-step transfer and cannot be renounced. `_feeBps` is capped at 500 (5%).
  Deposits revert if the recipient list changed since the depositor looked. A recipient who cannot receive USDC
  keeps a claimable balance. Recipients cannot be the contract itself, the USDC token or any address below `0x10000`.
- `StrPoints`: deposits, distributions and bridges made in the app go through it, so points are only awarded when
  the action succeeds. Because USDC is approved to this contract, the first deposit on each network asks for a new
  approval. The bridge fee is read live from the `SplitFactory`. `_dayLength` is `86400` (24 hours). Each
  deployment bridges to its paired chain (`_destinationDomain`).
- Names and tags can only be set by the split's creator.
- Known limits: if the fee recipient becomes blocklisted, deposits and bridges that carry a fee fail until the
  owner changes the recipient or sets the fee to 0. The platform fee and STR are credited when a bridge's burn
  confirms, because a contract cannot verify the destination chain. Only use normal wallet addresses as
  recipients. The contracts have had automated security reviews and unit, fuzz and invariant tests, but **no
  professional audit**.

## Testnet deployments (reference)

| Contract | Arc Testnet (chain 5042002) | Base Sepolia (chain 84532) | Arbitrum Sepolia (chain 421614) |
|---|---|---|---|
| `SplitFactory` | `0x1f311ff4b12cb107309b18f92bdaa63c4ab08e18` | `0xc0f3e95fb51fa186afadcefe045274e19096984f` | `0x4a062ebbff775a6b0c4f18550f4b559a91ff654e` |
| `StrPoints` | `0x9b534831098c6b1a9d5880662d8704d99af23c0a` | `0xa5d218ab623372d6ac54c84bb3db15ac7363015b` | `0x4935fc59c549c9e903d2a3b1c3ca92740f06f889` |
| `SplitNames` | `0x8b3a33056c27b3eba7c2bfb34e433f06edec6e00` | `0xaeba323c4d6bbf225e260be22cb7fd59540fa2dd` | `0x43621e37ba4f1e167238269ef3f0de9d0f46d2f1` |
| `RecipientLabels` | `0x8ef699dc26669979ab650f7b40ad17855b1fd649` | `0x66b74ecd715e67ba0426bfa309ff9a3975afc426` | `0xf36deac115e6818d2a5415c5105a0e014e2de867` |

Testnet settings: fee 50 bps (0.5%), `_dayLength` 86400. Explorers: `https://explorer.testnet.arc.io`,
`https://sepolia.basescan.org`, `https://sepolia.arbiscan.io`.

## Arbitrum Sepolia (testnet, third network)

Arbitrum Sepolia is **live**: its four contracts are deployed (addresses in the table above) and set in `src/network.ts`.
The deploy steps below are for redeploying it, or as the model for adding another network. If its four addresses in
`src/network.ts` are all set back to the zero placeholder, the app shows it as "Soon" and uses only Arc and Base.

| Setting | Value |
|---|---|
| Chain id | `421614` |
| RPC | `https://sepolia-rollup.arbitrum.io/rpc` |
| Explorer | `https://sepolia.arbiscan.io` |
| Gas token | ETH (the deployer needs a little Arbitrum Sepolia ETH) |
| USDC | `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` |
| CCTP domain | `3` |
| CCTP `TokenMessengerV2` | `0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA` |

**Deploy with the script.** It checks the network, USDC and messenger first, deploys in order, verifies all 11 values on-chain
and prints the four lines to paste. Nothing is spent if a check fails. These variables are read by the deploy script only,
not by the app:

```bash
export PRIVATE_KEY=0x...        # deployer key; set it in your shell, never in a file
export OWNER=0x...              # the wallet that can change the fee (use the same one as on Base)
export FEE_RECIPIENT=0x...      # where fees go (use the same one as on Base)
bun scripts/deploy-arbitrum-sepolia.ts
```

Optional: `FEE_BPS` (default 50, maximum 500), `RPC_URL`, and `FACTORY=0x...` to reuse an already deployed `SplitFactory`
if a later step failed. The script refuses to run if `src/network.ts` already has Arbitrum addresses (set `FORCE=1` to override).

**Or deploy by hand** (same order, same arguments). A keystore avoids putting the key on the command line:

```bash
cast wallet import deployer --interactive      # once; stores the key encrypted
export RPC=https://sepolia-rollup.arbitrum.io/rpc
export USDC=0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
export MESSENGER=0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA

forge create contracts/SplitFactory.sol:SplitFactory --rpc-url $RPC --account deployer --broadcast \
  --constructor-args $USDC $OWNER $FEE_RECIPIENT 50
export FACTORY=<"Deployed to" address above>

forge create contracts/StrPoints.sol:StrPoints --rpc-url $RPC --account deployer --broadcast \
  --constructor-args $FACTORY $USDC 86400 $MESSENGER 6
forge create contracts/SplitNames.sol:SplitNames --rpc-url $RPC --account deployer --broadcast --constructor-args $FACTORY
forge create contracts/RecipientLabels.sol:RecipientLabels --rpc-url $RPC --account deployer --broadcast --constructor-args $FACTORY
```

Then paste the four addresses into the `arbitrum` entry of `src/network.ts` (`factory`, `points`, `names`, `labels`).
The app starts using the network as soon as all four are set. If only some are set, it stops at startup with an error that
names the missing ones.

**Bridge routes.** Each `StrPoints` contract can bridge to one fixed network, chosen when it is deployed: the Arbitrum one
is deployed with destination `6`, so **Arbitrum to Base works, and Arbitrum is one-way**. Arc to Base and Base to Arc are
unchanged. Base to Arbitrum, Arc to Arbitrum and Arbitrum to Arc are not available.

## Stock Treasury (Base Sepolia only)

On Base, a disclosed share of the protocol fee is routed to a **stock treasury** wallet, and the Home page shows a
**Stock Treasury** card: the fee flow, the treasury's USDC and its test stock holdings. Arc and Arbitrum are not
involved and have no card. It earns no STR points and changes nothing about splits, points or the bridge.

**How it works.** A small `FeeRouter` contract becomes the Base `SplitFactory`'s fee recipient, so fees from deposits
and bridges arrive in the router in USDC. Anyone can press **Send to treasury** on the Stocks tab (it calls `flush()`): `stockFeeBps` of the
balance goes to the stock treasury and the rest to the normal fee wallet. If `stockFeeBps` is 0 or the treasury is
unset, all of it goes to the fee wallet, exactly as without the router. There is no swapping in this version.

| Contract / wallet | Base Sepolia |
|---|---|
| `FeeRouter` | `0x00d3e76c8e6e37b2fcf62cbee05236306593d25b` (owner = your owner wallet, 3000 bps = 30%) |
| Stock treasury wallet (testnet) | `0xe10abbc8c203a70a8aff5897385da9245b49ef59` |
| Fee wallet (the other 70%) | `0xb8183c1db227e2e53ae74a14cc28d6a3c6bfe11c` |
| `NVDAc` test token (25) | `0x1dd8bde6cd01ef1a752fd2521e4ef080fcba6600` |
| `AAPLc` test token (40) | `0x8a63fcb0e37cb933473058cc13b4189d69818d26` |
| `METAc` test token (10) | `0x7a63f69713e6798e8e4d37d3144d7f9f76cecc5c` |
| `GOOGLc` test token (15) | `0x4148e1727dc3f027371fcc057c252281555d0ac2` |
| `TSLAc` test token (30) | `0x8f98dd059530161778679b567f8d28b9378fc61f` |

The test tokens (`contracts/TestStock.sol`) are worthless, fixed-supply stand-ins, minted straight to the treasury,
because Base Sepolia has no real tokenized stocks. Their addresses live in the `stock` entry of the Base block in
`src/network.ts`; a zero address shows as "test token not deployed yet".

**Disclosure (shown on the Stocks page):** "Stocks are not bought automatically". Fees reach the treasury as USDC, and the holdings are simply whatever the treasury wallet holds. A "More" fold shows the treasury wallet and says that the app and the fee split contract cannot move it. On test networks it also says the test stocks use illustrative prices.

**Using a different treasury, for example on mainnet:** the page reads the treasury address live from the fee router, so it always shows the router's current setting and the note follows it. Pick the address with the router's constructor argument at deploy time, or change it later with `setStockTreasury(address)` from the router owner. The `treasury` value in the Base `stock` entry of `src/network.ts` is only a fallback shown before the router exists, so set it to the same wallet. Nothing in the note is tied to one wallet or network, and the test-token wording only appears while `priceBasis: 'illustrative'` is set.

**Dollar values (Stocks page):** each stock shows its value in USD, plus a total with the treasury's USDC. Base Sepolia's stocks are test tokens with no market price, so they use illustrative placeholder prices from `usdPrice` in the Base `stock` entry of `src/network.ts` (flat $100 each for now; edit freely) and the page labels them as illustrative. USDC counts at $1. A live price source would be added for real tokenized stocks.

**Checklist to switch it on (each step is yours, from the owner wallet)**

1. **Connect the router.** On Base, connect the owner wallet and open the **Stocks** tab, then press **Switch on the fee split** (the same setting is also in **Owner settings** at the bottom of Home).
   Set the fee recipient to the router address above and confirm. (Undo any time by setting it back to the fee wallet.)
   The card status should change to "Live".
2. **Test a deposit.** Deposit into any Base split. The card shows the fee waiting in the router.
3. **Route it.** Press **Send to treasury** on the Stocks tab. The treasury's USDC should rise by exactly 30% of the fees and the fee wallet
   should receive the other 70%.
4. **Test a bridge** from Base to Arc the same way (its platform fee also lands in the router).
5. **Change the split or treasury (optional).** On BaseScan, with the owner wallet: `setStockFeeBps` (0 to 10000),
   `setStockTreasury`, `setFeeRecipient`. Two-step ownership applies to the router.
6. **Missing or replaced test tokens (optional).** All five test tokens are deployed. To redeploy any of them yourself
   (needs a little Base Sepolia ETH), set its address in `src/network.ts` back to the zero placeholder and run the
   script below; it skips tokens that already exist, checks each one on-chain, and prints the lines to paste:

   ```bash
   export PRIVATE_KEY=0x...          # deployer key; set it in your shell, never in a file
   bun scripts/deploy-test-stocks.ts
   ```

If the treasury or the fee wallet cannot receive USDC, sending reverts and nothing is lost; the owner fixes the
address and routes again. Anyone can send the router USDC; it is treated as a fee on the next route.

**Not part of the mainnet package.** Mainnet has no `stock` entry, so the card never appears there. Real tokenized stock
addresses for a future mainnet version must come from base.org/stocks and be checked on-chain before use.

## Development

Prerequisites: [Foundry](https://book.getfoundry.sh/getting-started/installation) and [Bun](https://bun.sh/).

```bash
bun install
bun run dev            # app at http://localhost:5173
bun run build          # production build
forge build            # compile contracts
forge test             # run contract tests (needs forge-std in lib/)
bun run abi:sync       # after changing a contract: copy ABIs from forge's output into src/abi/
bun run check          # lint and typecheck
```

Environment variables: None.

Everything that differs between networks (chain IDs, USDC addresses, CCTP domains, the contract addresses and the
status-API URL) lives in one file, `src/network.ts`. Contract ABIs are committed in `src/abi/`, so the app builds
without compiling the contracts.

---

# Mainnet deployment guide

> **Warning:** Transactions on mainnet involve real funds and, once submitted, are irreversible. Arc Studio may
> generate or edit code or configuration that references mainnet, but Arc Studio does not deploy to, transact on,
> sign for, fund, or otherwise interact with mainnet on your behalf. Any code used for mainnet must be
> independently reviewed, tested, validated, deployed, and operated by you outside of Arc Studio. You are solely
> responsible for any losses, errors, or other consequences resulting from your use of any code, configuration, or
> output generated or edited through Arc Studio in connection with mainnet. Before proceeding, you should first use
> testnet, obtain an independent professional audit, and carefully review all wallet addresses, contract addresses,
> chain settings, permissions, and other configuration details. Only continue to mainnet after you have completed
> your independent review and have determined that you want to proceed.

This guide moves the working testnet app into your existing mainnet repository,
`github.com/simon4040/Payment-Splitter`, and deploys it on **Arc Mainnet and Base Mainnet**.

## Mainnet upgrade guide: add Arbitrum One and the Base Stock Treasury

> Warning: Transactions on mainnet involve real funds and, once submitted, are irreversible. Arc Studio may generate or edit code or configuration that references mainnet, but Arc Studio does not deploy to, transact on, sign for, fund, or otherwise interact with mainnet on your behalf. Any code used for mainnet must be independently reviewed, tested, validated, deployed, and operated by you outside of Arc Studio. You are solely responsible for any losses, errors, or other consequences resulting from your use of any code, configuration, or output generated or edited through Arc Studio in connection with mainnet. Before proceeding, you should first use testnet, obtain an independent professional audit, and carefully review all wallet addresses, contract addresses, chain settings, permissions, and other configuration details. Only continue to mainnet after you have completed your independent review and have determined that you want to proceed.

This guide upgrades `github.com/simon4040/Payment-Splitter` (checked at commit `e08ec40`). That repo already runs
**Arc Mainnet and Base Mainnet** with all four contracts on each. This upgrade does **not** redeploy any of those 8
contracts. It adds:

1. **Arbitrum One**: 4 new contracts (`SplitFactory`, `StrPoints`, `SplitNames`, `RecipientLabels`).
2. **Base Stock Treasury** (optional): 1 new contract, the `FeeRouter`, on Base only. Your live Base `SplitFactory` is
   **not** redeployed. You point its fee recipient at the router instead.
3. The newer app screens: Rewards tab, Stocks tab (Base), the PaySplit Protocol logo, safer explorer links.

### What your repo already has on-chain (checked: all linked and current)

| | Arc Mainnet (5042) | Base Mainnet (8453) |
|---|---|---|
| `SplitFactory` | `0x5A3EDbcC6406D99dE36ee159B56C6a5Ceb22843A` | `0x9336ef11392Db07873cca919EeD8A4C6Cc1bB881` |
| `StrPoints` | `0xe86fD18d14e8104E6108894bA34887737d75e83f` | `0x5Ea945f5491C73978cce56924c4dc92b3b1c3A38` |
| `SplitNames` | `0x87A180c552c220Ad592e144Ad69980dC08Ac8204` | `0x06e879972f9b24FB258100E9B3A9FeA060Df77D9` |
| `RecipientLabels` | `0x99dCa7934A1d8ad4FB335c92FF078d14260285dc` | `0x948787C73cF74Fa25800b57fcbDCa95a516187f2` |
| Fee / fee wallet | 50 bps / `0x7B5637640287a423F5094aD5F042D5cB0C1FBf6e` | 50 bps / `0x7B5637640287a423F5094aD5F042D5cB0C1FBf6e` |
| Owner of the factory | `0xf5AAf10c58a01fC27919Cc34a64C4F1c99ad7318` | `0xf5AAf10c58a01fC27919Cc34a64C4F1c99ad7318` |
| Bridge goes to | Base (domain 6) | Arc (domain 26) |

### What stays exactly as you have it

- **Your ERC-8021 Builder Code** (`src/attribution.ts`) and the `ox` package. The script never touches them. Every
  transaction in the app now goes through one wrapper (`src/hooks/useWrite.ts`) that adds your code, so a new button
  can never forget it. Tested: a plain approval is 68 bytes of calldata, with your code 97 bytes ending in your
  suffix, and the contract still accepts it.
- `package.json` (it has your `ox` dependency and the `prebuild` address check), `index.html`, `foundry.toml`,
  `.gitignore`, `public/`, `AGENTS.md`, `bun.lock`. No new packages are needed.

### Before you start

- Independent audit of the contracts (the four contracts, plus `FeeRouter` if you use it).
- ETH on **Arbitrum One** (gas) in the deployer wallet. For the optional router, ETH on **Base**.
- Foundry installed (`forge`, `cast`) and your deployer key set only in your shell, never in a file.
- Decide the wallets: the same owner (`0xf5AA…7318`) and fee wallet (`0x7B56…Bf6e`) you use on Arc and Base is the
  simplest choice. The owner controls the fee (up to 5%) and where fees go.

### Step 1: Copy the new files into your repo

```bash
bash mainnet/apply-to-repo.sh /path/to/Payment-Splitter
```

It copies **38 shared files** (20 new, 18 replaced) and **3 mainnet configuration files** (`src/network.ts`,
`src/config.ts`, `scripts/check-deployments.ts`). It deletes nothing and skips everything listed above under "stays
exactly as you have it". The full list, grouped by folder, is in [`docs/mainnet-files.md`](docs/mainnet-files.md).

### Step 2: Constants

| | Arbitrum One | Base Mainnet |
|---|---|---|
| Chain id | `42161` | `8453` |
| USDC (6 decimals) | `0xaf88d065e77c8cC2239327C5EDb3A432268e5831` | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| CCTP domain | `3` | `6` |
| CCTP `TokenMessengerV2` | `0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d` | `0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d` |
| Public RPC | `https://arb1.arbitrum.io/rpc` | `https://mainnet.base.org` |
| Explorer | `https://arbiscan.io` | `https://basescan.org` |

All of these were checked on-chain and against Circle's CCTP domain table. Arbitrum One is not in Arc Studio's built-in
chain list, so the app takes its explorer link from the wallet-chain settings instead (tested).

### Step 3: Deploy the 4 contracts on Arbitrum One

**Order matters:** `SplitFactory` first, because the other three need its address.

| # | Contract | Constructor (in this order) | Values for Arbitrum One |
|---|---|---|---|
| 1 | `SplitFactory` | `(address _usdc, address _owner, address _feeRecipient, uint16 _feeBps)` | `USDC`, your owner wallet, your fee wallet, `50` (0.5%, maximum 500) |
| 2 | `StrPoints` | `(address _factory, address _usdc, uint256 _dayLength, address _tokenMessenger, uint32 _destinationDomain)` | factory from #1, `USDC`, `86400`, `TokenMessengerV2`, `6` (Base) |
| 3 | `SplitNames` | `(address _factory)` | factory from #1 |
| 4 | `RecipientLabels` | `(address _factory)` | factory from #1 |

```bash
export RPC=https://arb1.arbitrum.io/rpc
export PRIVATE_KEY=0x...            # deployer key, in this shell only
export USDC=0xaf88d065e77c8cC2239327C5EDb3A432268e5831
export TOKEN_MESSENGER=0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d
export OWNER=0xf5AAf10c58a01fC27919Cc34a64C4F1c99ad7318
export FEE_RECIPIENT=0x7B5637640287a423F5094aD5F042D5cB0C1FBf6e

# 1. note the "Deployed to:" address and export it as FACTORY
forge create contracts/SplitFactory.sol:SplitFactory --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $USDC $OWNER $FEE_RECIPIENT 50
export FACTORY=0x...

# 2, 3, 4
forge create contracts/StrPoints.sol:StrPoints --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $FACTORY $USDC 86400 $TOKEN_MESSENGER 6
forge create contracts/SplitNames.sol:SplitNames --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $FACTORY
forge create contracts/RecipientLabels.sol:RecipientLabels --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $FACTORY
```

`--constructor-args` must be the **last** flag, because everything after it is read as an argument. Prefer a hardware
wallet or an encrypted keystore (`--account <name>`) over `--private-key` where you can.

Check each result (every line should print the value in brackets):

```bash
cast call $FACTORY "owner()(address)" --rpc-url $RPC          # [your owner]
cast call $FACTORY "feeRecipient()(address)" --rpc-url $RPC   # [your fee wallet]
cast call $FACTORY "feeBps()(uint16)" --rpc-url $RPC          # [50]
cast call $FACTORY "usdc()(address)" --rpc-url $RPC           # [USDC above]
cast call $POINTS "factory()(address)" --rpc-url $RPC         # [FACTORY]   (POINTS = address from #2)
cast call $POINTS "dayLength()(uint256)" --rpc-url $RPC       # [86400]
cast call $POINTS "tokenMessenger()(address)" --rpc-url $RPC  # [TokenMessengerV2]
cast call $POINTS "destinationDomain()(uint32)" --rpc-url $RPC # [6]
cast call $NAMES "factory()(address)" --rpc-url $RPC          # [FACTORY]
cast call $LABELS "factory()(address)" --rpc-url $RPC         # [FACTORY]
```

I ran these exact commands, and then a deposit and a bridge, against a local copy of Arbitrum One. All 11 checks
passed, and Circle's real messenger accepted the bridge to Base.

**Bridge routes:** each `StrPoints` bridges to **one** fixed destination chosen at deploy time. Arbitrum bridges to
Base only. Your live Base contract bridges to Arc, so Base to Arbitrum and anything involving Arbitrum and Arc are
shown in the app as "not available yet". Changing that needs a new `StrPoints` on Base, which resets Base points,
so it is not part of this upgrade.

### Step 4 (optional): Base Stock Treasury with the Fee Router

Skip this step if you do not want it. The Stocks tab stays hidden until you fill in step 5.

| Contract | Constructor | Values for Base Mainnet |
|---|---|---|
| `FeeRouter` | `(address _usdc, address _owner, address _feeRecipient, address _stockTreasury, uint16 _stockFeeBps)` | Base `USDC`; your owner wallet (the same one that owns the Base factory); the **current Base fee wallet** `0x7B56…Bf6e` (it keeps receiving the remaining share); **your stock treasury wallet**; `3000` (30%, 0 to 10000) |

```bash
export RPC=https://mainnet.base.org
export USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
export STOCK_TREASURY=0x...         # YOUR stock treasury wallet; do not use the zero address
forge create contracts/FeeRouter.sol:FeeRouter --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $USDC $OWNER $FEE_RECIPIENT $STOCK_TREASURY 3000
```

Then switch it on, **from the owner wallet that owns the Base factory** (one transaction, undoable): open the app on
Base, **Stocks** tab, press **Switch on the fee split** (or use **Owner settings** on Home and set the fee recipient
to the router address). From then on, Base deposit and bridge fees land in the router, and anyone can press **Send to
treasury** to split them: your chosen share (30%) to the treasury, the rest to your fee wallet. To undo, set the Base
factory's fee recipient back to `0x7B56…Bf6e`.

I tested this against your real Base Mainnet contracts on a local copy: a 20 USDC deposit and a 15 USDC bridge put
0.175 USDC of fees in the router, the split credited 19.90 USDC, STR was unchanged (+50), and one flush paid the
treasury exactly 30% and the fee wallet 70%.

Things to know:

- **Nothing buys stocks automatically.** The treasury receives USDC. The Stocks tab shows what the treasury wallet
  holds, and says so on the page.
- **Real tokens, read-only.** The five tokens in `src/network.ts` are the real Coinbase tokenized stocks on Base
  (symbols and company names read from the chain; all use **8 decimals**):

  | Token | Address |
  |---|---|
  | NVDAc (NVIDIA) | `0xb20000000000000000000078ee7ce2fE4908108C` |
  | AAPLc (Apple) | `0xb200000000000000000000C2e324d24d7eEcd1fb` |
  | METAc (Meta) | `0xb2000000000000000000008bC8786B856E61707C` |
  | GOOGLc (Alphabet) | `0xb2000000000000000000002D0BA3164cc74f58B7` |
  | TSLAc (Tesla) | `0xb2000000000000000000001e800a7f5189430cD0` |

  They follow their issuer's own rules, which cannot be inspected through standard contract calls, so check with the
  issuer whether your treasury wallet can hold them. The app can read their balances (tested on Base Mainnet).
- **No dollar values on mainnet.** The testnet page shows illustrative dollar prices for test tokens. Real prices
  need a live price source, so mainnet shows token quantities only.
- You can change the treasury or the percentage later with the router's owner-only `setStockTreasury` and
  `setStockFeeBps`; the page always shows the router's current setting.

### Step 5: Put the addresses in `src/network.ts`

Open `src/network.ts` in your repo (the script already put the final version there, with Arc and Base filled in).
You only edit two blocks:

```ts
  // Base: after step 4 (leave both as ZERO_ADDRESS to keep the Stocks tab hidden)
  stock: {
    router: '0x...',     // the FeeRouter you deployed
    treasury: '0x...',   // your stock treasury wallet (same as STOCK_TREASURY)
    tokens: [ /* already filled in with the real tokens */ ],
  },

  // Arbitrum One: after step 3 (all four, or none)
  arbitrum: {
    id: 42161,
    usdc: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
    cctpDomain: 3,
    factory: '0x...',    // 1. SplitFactory
    points: '0x...',     // 2. StrPoints
    names: '0x...',      // 3. SplitNames
    labels: '0x...',     // 4. RecipientLabels
  },
```

Nothing else in the app contains an address. The build refuses placeholders that are half filled in: Arbitrum with
only some addresses, or a router without a treasury. Arbitrum with none filled in simply stays off.

### Step 6: Build and try it locally

```bash
bun install
forge build && forge test    # optional: runs every contract test (the long invariant tests take a few minutes)
bun run build                # runs the address check first, then the production build
bun run dev                  # open http://localhost:5173 and connect your wallet
```

On a scratch copy of your repo with the script applied, the typecheck, lint, production build and `forge build` all
pass, and your Builder Code is present in the built files.

### Step 7: Publish to GitHub and deploy to Vercel

```bash
git add -A
git commit -m "Mainnet: Arbitrum One, Base Stock Treasury (fee router), Rewards tab"
git push
```

In Vercel (your existing project for this repo keeps its settings): Framework **Vite**, Install `bun install`, Build
`bun run build`, Output `dist`, **no environment variables**. Push, wait for the deployment, open it, then run step 8
before you share it. If the build stops with "Mainnet configuration is incomplete", an address in `src/network.ts`
is half filled in.

### Step 8: Smoke test with small amounts

On **Arbitrum One** (new), with a wallet holding a few USDC and some ETH:

1. Create a split with a name and tags, reload: name and tags remain.
2. Deposit 1 USDC: the preview shows 0.995 to the split and 0.005 fee. Confirm the fee wallet received 0.005.
3. Distribute, then check in on the Rewards tab.
4. Bridge 2 USDC to Base. The only destination offered is Base. Confirm the "You receive" amount and that the tracker
   reaches "Received".
5. Connect the owner wallet and change the fee and back (confirms you are the owner).

On **Base** (Stock Treasury), after switching the router on: make a 1 USDC deposit, press **Send to treasury**, and
confirm the treasury received exactly 30% of the 0.005 USDC fee and the fee wallet the rest.

On **Arc** and **Base** (existing): open the app and confirm your existing splits, names and points still show.

### Step 9: After launch

- Fill the table below and `AGENTS.md` with the new addresses.
- If you want your own page title in the browser tab: your `index.html` was not touched, so change its title to
  "PaySplit Protocol" yourself.
- Optional clean-up of old files is listed in [`docs/mainnet-files.md`](docs/mainnet-files.md).

### Mainnet deployments

| Contract | Arc Mainnet | Base Mainnet | Arbitrum One |
|---|---|---|---|
| `SplitFactory` | `0x5A3EDbcC6406D99dE36ee159B56C6a5Ceb22843A` | `0x9336ef11392Db07873cca919EeD8A4C6Cc1bB881` | _fill in_ |
| `StrPoints` | `0xe86fD18d14e8104E6108894bA34887737d75e83f` | `0x5Ea945f5491C73978cce56924c4dc92b3b1c3A38` | _fill in_ |
| `SplitNames` | `0x87A180c552c220Ad592e144Ad69980dC08Ac8204` | `0x06e879972f9b24FB258100E9B3A9FeA060Df77D9` | _fill in_ |
| `RecipientLabels` | `0x99dCa7934A1d8ad4FB335c92FF078d14260285dc` | `0x948787C73cF74Fa25800b57fcbDCa95a516187f2` | _fill in_ |
| `FeeRouter` (optional) | | _fill in_ | |
| Stock treasury wallet | | _fill in_ | |

### Mainnet warnings

1. Every transaction moves real USDC and cannot be undone.
2. Get an independent professional audit before holding significant funds.
3. Check every address on the explorer before depositing. Constructor values cannot be changed afterwards.
4. The owner wallet controls the protocol fee (up to 5%) and where fees go, and, on Base, the fee router's settings.
   Protect it, ideally with a hardware wallet or a multisig.
5. The stock treasury wallet's keyholder alone decides what happens to its USDC and tokens. Nothing here buys or sells
   stocks for you.
6. Never commit your private key or paste it into a file.
7. Bridges are real transfers: always test with a small amount first.

---

## Project layout

| Path | Purpose |
|------|---------|
| `contracts/` | `SplitFactory.sol`, `StrPoints.sol`, `SplitNames.sol`, `RecipientLabels.sol`, plus tests in `contracts/test/` |
| `src/network.ts` | Chain IDs, USDC, CCTP domains, contract addresses, status-API URL (the only file that differs between testnet and mainnet, with `src/config.ts`) |
| `src/contract.ts` | Builds the per-network setup from `src/network.ts` and the ABIs |
| `src/abi/` | Committed contract ABIs (`bun run abi:sync` refreshes them) |
| `src/config.ts` | Wallet and chain setup |
| `src/bridge.ts` | Bridge fee quote, transfer status and in-progress tracking |
| `src/App.tsx` | Page shell and tab navigation |
| `src/components/` | Pages and widgets: Home, Bridge, Rewards (points and leaderboard), Stocks (Base only), split page, create form, owner settings |
| `src/hooks/` | Reads for points, names, tags, fees and split lists |
| `mainnet/` | The mainnet-only files and the copy script used in step 1 |
| `docs/mainnet-files.md` | The complete file-by-file comparison with your mainnet repo |
