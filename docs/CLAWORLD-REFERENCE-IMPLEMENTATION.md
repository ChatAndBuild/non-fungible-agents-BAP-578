# Clawworld Reference Implementation

Clawworld is a production BNB Chain project showing how BAP-578 NFAs can grow into persistent on-chain role units instead of stopping at ownership and metadata.

## Why This Reference Matters

Most examples around agent NFTs still stay close to the base contract layer. They show identity, metadata, and perhaps a logic address, but they stop before the asset becomes something a player can actually manage over time.

Clawworld pushes that farther. Each lobster NFA acts as a stateful role unit with:

- persistent on-chain identity
- per-agent balance accounting
- active and dormant state
- level and XP progression
- five-dimension personality
- battle statistics and match history
- market behavior
- world-state driven rule changes

This makes it a useful BAP-578 reference for projects that want to build long-lived agent economies rather than a thin collectible layer.

## What Clawworld Adds On Top of the Base NFA Layer

Clawworld keeps the core idea of an NFA as a single owned role unit, then extends it into a game and economy system.

### 1. Persistent role state

Each NFA carries more than ownership. It also carries rarity, shelter origin, personality, combat stats, level, XP, active status, and internal Claworld balance.

### 2. Internal per-agent accounts

Value is tracked at the agent level, not only at the wallet level. That means a lobster can earn, spend, stake, and carry balance as a role unit inside the system.

### 3. Executable gameplay loop

The NFA can participate in:

- tasks
- PK matches
- marketplace listings
- upkeep and dormancy logic
- world-state driven parameter shifts

### 4. Learning and behavioral drift

Personality is not decorative metadata. It changes based on player behavior and then feeds back into rewards, role fit, and future outcomes.

### 5. Multi-surface usage

The same on-chain role unit is exposed through:

- a browser terminal UI
- a Phaser browser game
- a local OpenClaw skill CLI

That last point matters. A BAP-578 NFA becomes much easier to understand when the same role unit can be read by both players and models through stable interfaces.

## Clawworld as a BAP-578 Usage Layer

One useful way to read Clawworld is as a gameplay layer sitting above a BAP-578-compatible identity and state base.

At the bottom, the NFA defines who the agent is.

Above that, Clawworld adds:

- task execution
- strategic PK
- market exchange
- internal accounting
- world-state modulation
- personality-driven outcomes

This helps show how BAP-578 can support more than ownership. It can support systems where an NFA starts to feel closer to an on-chain character account.

## Production Links

- Main repo: [fa762/ClaworldNfa](https://github.com/fa762/ClaworldNfa)
- Website: [clawnfaterminal.xyz](https://www.clawnfaterminal.xyz)
- Browser game: [clawnfaterminal.xyz/game](https://www.clawnfaterminal.xyz/game)
- Skill source: [fa762/claw-world-skill](https://github.com/fa762/claw-world-skill)
- Skill hub page: [clawhub.ai/fa762/claw-world](https://clawhub.ai/fa762/claw-world)

## Suggested Reading

- [Clawworld Architecture](./CLAWORLD-ARCHITECTURE.md)
- [Clawworld Economic Model](./CLAWORLD-ECONOMIC-MODEL.md)
- [Clawworld Skill CLI](./CLAWORLD-SKILL-CLI.md)
