# Clawworld Skill CLI

Clawworld exposes its NFA system through a local skill CLI built on [OpenClaw](https://clawhub.ai). This gives AI models a stable, command-driven interface to read and operate BAP-578 role units without requiring a browser session.

## Why a Skill CLI Matters for BAP-578

BAP-578 defines "execution" as a core capability. The skill CLI is where that capability becomes real for AI models:

- **A model can read role state** — level, XP, balance, personality, combat record
- **A model can reason about strategy** — which tasks to run, when to PK, risk assessment
- **A model can execute actions** — submit tasks, check rewards, manage the role

Without this layer, the NFA is only accessible through a browser UI. With it, the same role unit becomes a runtime surface for any model that can call a command.

### 1. End-to-end local usage

The skill runs locally on the user's machine. No API keys, no hosted service. That makes it easy to build private or user-controlled AI workflows around a BAP-578 role unit.

### 2. Stable state readability

The CLI returns structured output that models can parse reliably:

- balance (internal CLW + external wallet)
- lifecycle status (active / dormant)
- personality (five-axis values)
- PK match history and win rate
- task record and reward history

### 3. Multiple surfaces, one role

The same Clawworld lobster can be:

- viewed through the **web terminal** — human-facing dashboard
- played inside the **browser game** — visual Phaser interface
- queried and operated through the **skill CLI** — model-facing commands

All three surfaces read the same on-chain state from the same contracts. No state duplication, no identity split.

## Production Commands

The skill exposes these commands in production:

```bash
claw status <tokenId>                              # Full role state: rarity, level, XP, balance, personality, stats
claw task <pin> <nfaId> <type> <xp> <clw> <score>  # Execute a task with specified parameters
claw wallet                                         # Connected wallet info and CLW balance
claw balance <address>                              # Check CLW balance for any address
```

Each command reads from the deployed BSC mainnet contracts (ClawRouter, ClawNFA, TaskSkill) and returns structured, parseable output.

## How It Connects to BAP-578

| BAP-578 Capability | Skill CLI Coverage |
|--------------------|-------------------|
| **Identity** | `claw status` reads rarity, origin, metadata from ClawNFA |
| **Wallet** | `claw balance` / `claw wallet` reads internal + external CLW from ClawRouter |
| **Execution** | `claw task` triggers TaskSkill execution through the CLI |
| **Learning** | `claw status` returns personality values that drift with behavior |

This maps the four BAP-578 capabilities directly into a model-operable command interface.

## Production References

- Skill hub page: [clawhub.ai/fa762/claw-world](https://clawhub.ai/fa762/claw-world)
- Skill source: [fa762/claw-world-skill](https://github.com/fa762/claw-world-skill)
- Main project repo: [fa762/ClaworldNfa](https://github.com/fa762/ClaworldNfa)

## Why This Belongs in a BAP-578 Reference

The skill CLI is not a convenience wrapper. It is a concrete answer to:

> How does a BAP-578 role unit become usable by AI models in practice?

It demonstrates:

- **Local AI runtime integration** — no hosted dependency
- **Deterministic command structure** — predictable input/output for model workflows
- **Full role-state readability** — everything an agent needs to make decisions
- **Multi-surface access** — same NFA, same state, different consumers

This makes it a meaningful companion reference for teams implementing the BAP-578 standard who want to go beyond browser-only interaction.
