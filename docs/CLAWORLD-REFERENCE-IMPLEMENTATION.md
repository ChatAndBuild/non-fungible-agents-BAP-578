# Clawworld — BAP-578 Production Case Study

Clawworld is a live BNB Chain project that takes the BAP-578 NFA standard beyond ownership and metadata into a full on-chain game economy. Eleven UUPS-upgradeable proxy contracts run on BSC mainnet. The system has been in production since March 2026.

## Why This Reference Matters

Most BAP-578 examples stay close to the base contract layer — identity, metadata, maybe a logic address. They stop before the asset becomes something a player can manage over time.

Clawworld pushes further. Each lobster NFA acts as a persistent role unit with:

- on-chain identity (ERC-721, rarity tier, shelter origin)
- per-agent CLW balance accounting (deposit, earn, spend, withdraw)
- active and dormant lifecycle state
- level / XP progression
- five-dimension personality that drifts with behavior
- battle statistics and match history
- market listing, auction, and swap behavior
- world-state driven rule changes (dynamic multipliers)

This makes it a concrete BAP-578 production reference for teams building long-lived agent economies rather than thin collectible layers.

## Mainnet Deployment

All contracts are deployed on **BNB Smart Chain mainnet (chain 56)** as UUPS-upgradeable proxies.

| Contract | Role | Proxy Address |
|----------|------|---------------|
| ClawNFA | ERC-721 identity + rarity + metadata | `0xAa2094798B5892191124eae9D77E337544FFAE48` |
| ClawRouter | State router — level, XP, internal balance, permissions | `0x60C0D5276c007Fd151f2A615c315cb364EF81BD5` |
| WorldState | Global parameter control (reward / upkeep / PK multipliers) | `0xC375E0a2f4e06cF79b4571AB4d2f6118482b9FCA` |
| GenesisVault | Treasury + payout vault | `0xCe04f834aC4581FD5562f6c58C276E60C624fF83` |
| FlapPortal | BNB → CLW on-ramp via PancakeSwap | `0x3525e9B10cD054E7A32248902EB158c863F3a18B` |
| DepositRouter | External CLW → internal balance bridge | `0xFe68460e9C55AB188b1E91fd4dB4D7219Bd3f269` |
| PersonalityEngine | Five-axis personality drift + mutation | `0x19E8A11d8b6E94230f0C174f6Fc4Ca11e6f4331E` |
| TaskSkill | PvE task execution + reward distribution | `0xaed370784536e31BE4A5D0Dbb1bF275c98179D10` |
| MarketSkill | Fixed-price, auction, and swap marketplace | `0x6e3d89B36a7f396143Ff123e8a40F66FE2382a54` |
| PKSkill | 1v1 PvP — stake, match, settle, burn | `0xA58e9E0D5f3970d46c9779a9A127DdAc60508dfF` |
| BattleRoyale | 10-room battle royale — multi-player CLW stake + future-block-hash randomness | `0x2B2182326Fd659156B2B119034A72D1C2cC9758D` |

CLW token: `0x3b486c191c74c9945fa944a3ddde24acdd63ffff`

Every address is verifiable on [BscScan](https://bscscan.com).

## Codebase Scale

- **20 Solidity source files** (4 core, 5 skill, 2 world, 5 interface, 4 mock)
- **11 UUPS proxy contracts** deployed to mainnet
- **10 test suites**, 3 500+ lines of TypeScript test code covering unit, integration, and upgrade paths
- **3 user-facing surfaces**: web terminal, Phaser browser game, local OpenClaw skill CLI

## What Clawworld Adds On Top of the Base NFA Layer

### 1. Persistent role state

Each NFA carries rarity, shelter origin, personality, combat stats, level, XP, active status, and its own internal CLW balance. State lives on-chain in ClawRouter, not off-chain.

### 2. Internal per-agent accounts

Value is tracked at the agent level, not just the wallet level. A lobster can earn, spend, stake, and carry balance as a role unit inside the system. The vault layer converts internal balance to the circulating CLW token on withdrawal.

### 3. Executable gameplay loop

The NFA participates in:

- **tasks** — PvE missions with role-fit and world-state dependent rewards (TaskSkill)
- **PK** — 1v1 staked matches with burn + redistribution (PKSkill)
- **Battle Royale** — 10-room survival, future-block-hash randomness, no backend required (BattleRoyale)
- **marketplace** — fixed-price sales, auctions, swaps (MarketSkill)
- **upkeep + dormancy** — roles that stop paying upkeep drift toward inactive state

### 4. Learning and behavioral drift

Personality is not decorative metadata. The PersonalityEngine tracks five axes that shift based on player behavior and feed back into rewards, role fit, and future outcomes. This is BAP-578 "learning" made concrete.

### 5. Multi-surface usage

The same on-chain role unit is exposed through:

- **browser terminal** — dashboard + contract interaction at [clawnfaterminal.xyz](https://www.clawnfaterminal.xyz)
- **Phaser browser game** — visual map, shelter, PK arena, Battle Royale at [clawnfaterminal.xyz/game](https://www.clawnfaterminal.xyz/game)
- **local OpenClaw skill CLI** — model-facing command interface at [clawhub.ai/fa762/claw-world](https://clawhub.ai/fa762/claw-world)

That last point matters for BAP-578: the same role can be read and operated by both players and AI models through stable interfaces.

## Battle Royale — Newest Skill (April 2026)

The most recent addition demonstrates that the architecture is genuinely extensible:

- **10 rooms**, 10 players trigger a round
- Players stake CLW into a room; can **change rooms** and **add stake** before the round triggers
- Randomness uses **future block hash** (`blockhash(triggerBlock + 5)`) — no oracle, no backend. Note: on BSC's 21-validator set this is adequate for game-level stakes but not suitable for high-value lotteries; teams adapting this pattern should evaluate their own risk threshold
- Losing room: 10% → treasury, 90% → survivors proportionally (push distribution, no claim step)
- Multiple concurrent matches with permanent IDs (match 1 is always match 1)
- Deployed as a new UUPS skill contract without touching any existing contract

This shows how BAP-578 execution can grow over time: a new game mechanic ships as a new authorized skill module while the identity, state, and account layers remain untouched.

## Clawworld as a BAP-578 Usage Layer

One useful way to read Clawworld is as a gameplay layer sitting above a BAP-578-compatible identity and state base.

At the bottom, the NFA defines who the agent is.

Above that, Clawworld adds:

- task execution
- strategic PK and battle royale
- market exchange
- internal accounting
- world-state modulation
- personality-driven outcomes

This shows how BAP-578 can support systems where an NFA starts to feel closer to an on-chain character account with real economic weight.

## Production Links

- Main repo: [fa762/ClaworldNfa](https://github.com/fa762/ClaworldNfa)
- Website: [clawnfaterminal.xyz](https://www.clawnfaterminal.xyz)
- Browser game: [clawnfaterminal.xyz/game](https://www.clawnfaterminal.xyz/game)
- Skill source: [fa762/claw-world-skill](https://github.com/fa762/claw-world-skill)
- Skill hub page: [clawhub.ai/fa762/claw-world](https://clawhub.ai/fa762/claw-world)
- BscScan (ClawNFA): [bscscan.com/address/0xAa2094798B5892191124eae9D77E337544FFAE48](https://bscscan.com/address/0xAa2094798B5892191124eae9D77E337544FFAE48)

## Suggested Reading

- [Clawworld Architecture](./CLAWORLD-ARCHITECTURE.md) — BAP-578 four-capability mapping
- [Clawworld Economic Model](./CLAWORLD-ECONOMIC-MODEL.md) — two-layer asset design + treasury flywheel
- [Clawworld Showcase](./CLAWORLD-SHOWCASE.md) — end-to-end user flow
- [Clawworld Skill CLI](./CLAWORLD-SKILL-CLI.md) — model-facing runtime layer
