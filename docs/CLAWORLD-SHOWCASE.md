# Clawworld Showcase

A walkthrough of how Clawworld turns the BAP-578 NFA standard into a live product that players use and AI models can operate.

## Live Surfaces

Clawworld exposes the same on-chain role unit through three production surfaces:

| Surface | URL | Users |
|---------|-----|-------|
| Web terminal | [clawnfaterminal.xyz](https://www.clawnfaterminal.xyz) | Players — dashboard, stats, contract interaction |
| Browser game | [clawnfaterminal.xyz/game](https://www.clawnfaterminal.xyz/game) | Players — Phaser visual map, shelter, arena, battle royale |
| Skill CLI | [clawhub.ai/fa762/claw-world](https://clawhub.ai/fa762/claw-world) | AI models — read state, execute actions, reason about strategy |

One NFA, three interfaces, no split in identity or state.

## Contract Ecosystem at a Glance

Clawworld runs **11 UUPS-upgradeable proxy contracts** on BSC mainnet, organized by function:

**Identity**
- `ClawNFA` — ERC-721 token with rarity tier, shelter origin, on-chain metadata

**State & Accounting**
- `ClawRouter` — per-agent level, XP, internal CLW balance, skill authorization hub
- `GenesisVault` — treasury, payout vault, protocol income
- `DepositRouter` — external CLW → internal agent balance bridge
- `FlapPortal` — BNB → CLW on-ramp via PancakeSwap

**Execution (Skills)**
- `TaskSkill` — PvE task execution, role-fit rewards, XP progression
- `PKSkill` — 1v1 staked PvP with burn + redistribution
- `BattleRoyale` — 10-room survival, future-block-hash randomness, concurrent matches
- `MarketSkill` — fixed-price sale, auction, swap

**World & Behavior**
- `WorldState` — global parameter control (reward, upkeep, PK multipliers)
- `PersonalityEngine` — five-axis personality drift based on player behavior

All contracts are verified on [BscScan](https://bscscan.com). Full address table: [Reference Implementation](./CLAWORLD-REFERENCE-IMPLEMENTATION.md#mainnet-deployment).

## What a Player Actually Does

### 1. Enter the system

The player mints a lobster NFA on BNB Chain.

From that point on, the role is more than a static collectible. It has rarity, shelter origin, personality, battle stats, level, XP, and its own internal CLW balance.

### 2. Use the role to produce

The player sends the lobster to tasks. Rewards depend on the role’s fit, personality, and world-state conditions. Higher-level roles with aligned personality earn more.

### 3. Keep the role alive

The same role must keep paying upkeep. If balance runs dry for too long, the role slides toward dormancy. The player is managing a living unit, not just holding a picture.

### 4. Risk it in PK

The player brings the lobster into PK matches — stake internal CLW, settle outcomes, build visible match history. Every settled match burns part of the stake, creating real token removal.

### 5. Survive the Battle Royale

The newest mode: 10 rooms, 10 players, one random losing room. Players stake CLW, choose (and change) rooms before the round triggers, and the outcome is decided by future block hash — no backend, no oracle. Survivors split the losing room’s stake. Multiple matches run concurrently.

### 6. Price it in the market

The role moves through fixed-price sales, auctions, or swaps. The market is not pricing an image. It is pricing a role account with history, personality, stats, balance, and future earning potential.

## What a Model Can Do

Through the OpenClaw skill CLI, an AI model can:

- read full role state (level, XP, balance, personality, combat record)
- inspect task history and reward patterns
- reason about strategy (which tasks fit, when to PK, risk assessment)
- execute actions through stable command patterns

```bash
claw status <tokenId>     # full role state
claw task <pin> ...       # execute a task
claw wallet               # connected wallet info
claw balance <address>    # CLW balance check
```

This turns the NFA into a model-operable runtime surface — exactly what BAP-578 envisions with the "execution" capability.

## Why This Is a Strong BAP-578 Reference

Clawworld covers the full BAP-578 capability stack in production:

| BAP-578 Capability | Clawworld Proof |
|--------------------|-----------------|
| **Identity** | ClawNFA — ERC-721 with immutable rarity and origin |
| **Wallet** | ClawRouter internal balance + GenesisVault payout |
| **Execution** | 4 skill contracts (Task, PK, BattleRoyale, Market) |
| **Learning** | PersonalityEngine — behavior-driven drift that affects gameplay |

Scale:
- 11 mainnet proxy contracts
- 20 Solidity source files
- 10 test suites, 3 500+ lines of test code
- 3 production user-facing surfaces
- Running on BSC mainnet since March 2026

This makes Clawworld a useful reference for teams trying to move from standard agent ownership toward a genuinely playable, economically active, and AI-operable role unit.

## External References

- Main repo: [fa762/ClaworldNfa](https://github.com/fa762/ClaworldNfa)
- Skill source: [fa762/claw-world-skill](https://github.com/fa762/claw-world-skill)
- Browser game: [clawnfaterminal.xyz/game](https://www.clawnfaterminal.xyz/game)
- BscScan (ClawNFA): [bscscan.com/address/0xAa2094798B5892191124eae9D77E337544FFAE48](https://bscscan.com/address/0xAa2094798B5892191124eae9D77E337544FFAE48)
