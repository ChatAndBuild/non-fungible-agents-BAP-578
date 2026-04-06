# Clawworld Architecture

This note explains how Clawworld turns a BAP-578-style NFA into a usable role unit across contracts, gameplay systems, and AI-facing tooling.

## Core Idea

Clawworld treats each NFA as a persistent role account. Ownership still matters, but the agent also carries state, balance, permissions, and behavior over time.

## Layer Map

### Base role layer

The core NFA contract establishes:

- ownership
- rarity and identity
- metadata entry point
- upgrade-safe lifecycle

This is the part that stays closest to the base BAP-578 idea.

### State and account layer

Above that sits a router-style state layer which tracks:

- level
- XP
- internal Claworld balance
- active or dormant state
- personality values
- combat stats

This is where Clawworld starts to feel different from a standard collectible. A lobster is no longer just held. It is managed like a role account.

### Execution layer

Execution is split into separate skill contracts:

- tasks
- PK
- market
- personality evolution

This keeps the system modular. New behaviors can be added without collapsing everything into one contract.

### World-state layer

A separate world-state contract controls global parameters such as:

- task reward multiplier
- upkeep multiplier
- PK stake cap
- mutation bonus

This gives the economy a changing environment instead of fixed forever parameters.

### Usage layer

Clawworld exposes the same underlying NFA through three user-facing surfaces:

- a web terminal
- a browser game
- a local skill CLI

That matters for BAP-578 because it demonstrates how one role unit can be consumed by different interfaces without splitting the underlying identity.

## Why This Structure Is Useful

The architecture shows a practical answer to a common BAP-578 question:

How does an NFA move from "an owned agent object" to "a persistent playable unit"?

Clawworld’s answer is:

1. keep ownership stable
2. attach state to the role itself
3. let authorized execution modules mutate that state
4. expose the result through tools that players and models can both use

## External References

- Main repo: [fa762/ClaworldNfa](https://github.com/fa762/ClaworldNfa)
- Skill source: [fa762/claw-world-skill](https://github.com/fa762/claw-world-skill)
- Live site: [clawnfaterminal.xyz](https://www.clawnfaterminal.xyz)
