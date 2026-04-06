# Clawworld Architecture

This document explains how Clawworld maps the BAP-578 NFA standard into a multi-contract gameplay system on BNB Chain. All 11 contracts are live on BSC mainnet as UUPS-upgradeable proxies.

## BAP-578 Four-Capability Mapping

BAP-578 defines four core capabilities for a Non-Fungible Agent. Clawworld implements all four:

| BAP-578 Capability | Clawworld Contract | What It Does |
|--------------------|--------------------|--------------|
| **Identity** | ClawNFA (ERC-721) | Mint, ownership, rarity tier, shelter origin, on-chain metadata. The base token that everything else references. |
| **Wallet** | ClawRouter + GenesisVault + DepositRouter | Per-agent internal CLW balance, deposit from external wallet, earn from tasks, spend on upkeep, withdraw through vault with payout ratio. |
| **Execution** | TaskSkill, PKSkill, BattleRoyale, MarketSkill | Modular skill contracts authorized by ClawRouter. Each skill reads/writes agent state. New skills deploy without touching existing contracts. |
| **Learning** | PersonalityEngine | Five-axis personality (aggression, caution, social, creative, analytical) that drifts based on player behavior and feeds back into reward multipliers, role fit, and strategic outcomes. |

This is not a loose analogy. Each capability corresponds to a deployed, verifiable contract on BSC mainnet.

## Core Idea

Clawworld treats each NFA as a persistent role account. Ownership still matters, but the agent also carries state, balance, permissions, and behavior that evolve over time.

## Layer Map

### 1. Base identity layer — ClawNFA

The core NFA contract establishes:

- ERC-721 ownership
- rarity tier and shelter origin (set at mint, immutable)
- on-chain metadata entry point
- UUPS upgrade-safe lifecycle

This is the part that stays closest to the base BAP-578 identity definition.

### 2. State and account layer — ClawRouter + GenesisVault

Above identity sits a router-style state layer which tracks:

- level and XP
- internal CLW balance (per-agent, not per-wallet)
- active or dormant lifecycle state
- personality values (via PersonalityEngine)
- combat stats and match history
- skill authorization (which contracts can mutate agent state)

This is where Clawworld diverges from a standard collectible. A lobster is no longer just held — it is managed like a character account with its own balance sheet.

### 3. Execution layer — Skill contracts

Execution is split into separate authorized skill contracts:

| Skill | Purpose |
|-------|---------|
| TaskSkill | PvE task execution, role-fit rewards, XP gain |
| PKSkill | 1v1 staked PvP, burn + redistribution |
| BattleRoyale | 10-room survival, future-block-hash randomness, concurrent matches |
| MarketSkill | Fixed-price sale, auction, swap |
| PersonalityEngine | Personality drift based on behavior |

This keeps the system modular. BattleRoyale was added in April 2026 without modifying any existing contract — it deployed as a new UUPS proxy and was authorized through ClawRouter.

### 4. World-state layer — WorldState

A separate contract controls global parameters:

- task reward multiplier
- upkeep multiplier
- PK stake cap
- mutation bonus

This gives the economy a living environment. Parameters can shift in response to ecosystem health, creating seasons and pressure cycles.

### 5. Usage layer — Three surfaces, one role

Clawworld exposes the same underlying NFA through three user-facing surfaces:

- **Web terminal** — dashboard, stats, contract interaction
- **Phaser browser game** — visual map with shelter, arena, and battle royale
- **OpenClaw skill CLI** — model-facing command interface for AI agents

That matters for BAP-578 because it proves one role unit can be consumed by both human players and AI models through stable interfaces, without splitting identity or state.

## Contract Dependency Flow

```
ClawNFA (identity)
    │
    ▼
ClawRouter (state hub) ◄── WorldState (global params)
    │
    ├── TaskSkill
    ├── PKSkill
    ├── BattleRoyale
    ├── MarketSkill
    ├── PersonalityEngine
    │
    ▼
GenesisVault ◄── DepositRouter ◄── FlapPortal (BNB→CLW)
```

All skill contracts call into ClawRouter to read and write agent state. ClawRouter checks authorization before allowing mutations. This hub-and-spoke design means new skills plug in without architectural changes.

## Why This Structure Answers the BAP-578 Question

The architecture provides a concrete answer to:

> How does an NFA move from "an owned agent object" to "a persistent playable unit"?

Clawworld’s answer:

1. **Keep identity stable** — ClawNFA never changes after mint
2. **Attach state to the role itself** — ClawRouter holds per-agent data, not per-wallet
3. **Let authorized modules mutate state** — skill contracts are the only writers
4. **Expose the result through multiple surfaces** — terminal, game, and CLI all read the same on-chain state

This is not theoretical. Every layer is a deployed contract, every state mutation is an on-chain transaction, and the system has been running in production on BSC mainnet since March 2026.

## External References

- Main repo: [fa762/ClaworldNfa](https://github.com/fa762/ClaworldNfa)
- Skill source: [fa762/claw-world-skill](https://github.com/fa762/claw-world-skill)
- Live site: [clawnfaterminal.xyz](https://www.clawnfaterminal.xyz)
- BscScan (ClawNFA): [bscscan.com/address/0xAa2094798B5892191124eae9D77E337544FFAE48](https://bscscan.com/address/0xAa2094798B5892191124eae9D77E337544FFAE48)
