# Example agent logic modules

Reference implementations of BAP-578 logic modules: the contract a BAP-578 NFT
points its `logicAddress` at, and the thing the standard's `handleAction` entry
point dispatches into.

These are real contracts deployed and running on BSC mainnet, provided so that
anyone building a BAP-578 agent has a complete, working example to read. They
are not proposed as part of the BAP-578 core spec. Maintainers are free to keep,
relocate, or decline them.

## Contracts

| File | Mainnet address | What it does |
|---|---|---|
| `logic/HunterAgentLogic.sol` | `0x4F35D6B3DEdecfe3aD6600b39A705BcD53E2aE81` | Position-tracking trading agent (stop-loss / take-profit, PancakeSwap + FourMeme). |
| `logic/CTOAgentLogic.sol` | `0x8E54612c12710c41ae57abAa8D4637f394DE2b0B` | Campaign agent (multi-tranche entry / exit plus social actions). |
| `logic/MetricsTracker.sol` | base contract | Shared metrics base (`getMetrics`, action / trade counters). |
| `interfaces/IPlatformRegistry.sol` | interface | Off-chain platform registry interface. |

The source here is byte-identical to the verified source on BscScan at each
address above.

## The pattern they demonstrate

- **`handleAction(uint256 tokenId, string action, bytes payload)`** is the single
  write entry point. It is `onlyAuthorized whenNotPaused nonReentrant`, dispatches
  on the action string, and returns `(bool success, bytes result)`.
- **`getMetrics(uint256 tokenId)`** is the read surface for indexers and front
  ends: action counts, trade counts, lifetime PnL, active positions.
- **Authorized callers**: an `authorizedCallers` set gates `handleAction`, so a
  forwarder (for example a `VaultPermissionManager`) can be authorized to drive
  the agent without being the NFT owner.
- **Owner controls**: two-step ownership, `pause` / `unpause`, slippage and gas
  bounds.

## Compilation

`HunterAgentLogic` and `CTOAgentLogic` are large. The root `hardhat.config.js`
has a scoped `overrides` block that compiles those two at `solc 0.8.19` with
`viaIR` and `optimizer runs: 1`, which is the configuration they were deployed
with and which keeps them under the 24 KB EVM code-size limit.

## Static-analysis notes

Static analyzers and AI reviewers flag a few patterns in these contracts. Each
has been reviewed:

- **`_reimburseGas` "sends ETH to arbitrary user"**: it reimburses `msg.sender`
  (the authorized action caller) for gas actually spent, debited from the agent's
  own tracked BNB balance. The recipient is the caller and the amount is bounded.
- **`received == 0` / `bnbReceived == 0` strict equality**: these are zero-guards
  on values already measured as balance deltas
  (`balanceAfter - balanceBefore`). They are not equality checks against an
  expected amount, so they are correct for fee-on-transfer tokens. The swap paths
  also use `swapExactETHForTokensSupportingFeeOnTransferTokens`.
- **Reentrancy on swap / deposit paths**: every external entry point
  (`handleAction`, `depositToken`, `depositBNB`, the emergency withdrawals)
  carries `nonReentrant`. Internal helpers do not carry the modifier because
  their public callers already hold it.
- **`bap578.ownerOf(tokenId)` return value ignored**: the call is made as a
  token-exists guard (it reverts for a non-existent token); the returned address
  is intentionally unused.

## Known limitations

- **`check_positions` returns a custom-packed layout.** `HunterAgentLogic`'s
  `check_positions` action returns `abi.encode(uint256 count)` followed by one
  `abi.encode(...)` per position concatenated with `abi.encodePacked`. This is
  not a standard ABI array, so `abi.decode` of the whole blob as a tuple array
  will not work. An off-chain consumer reads the leading 32-byte `count`, then
  decodes each following fixed 224-byte chunk as
  `(address, uint256, uint256, uint256, uint256, uint256, bool)`.
