# Clawworld Skill CLI

Clawworld also exposes its NFA system through a local skill CLI built on top of OpenClaw.

This layer matters because it answers a practical BAP-578 question:

How does an on-chain role unit become readable and usable for models without forcing everything through a custom web UI?

## Why a Skill CLI Matters

The skill CLI gives Clawworld a stable usage layer for model-facing interaction.

It lets a model read role state and execute game-relevant actions through predictable command structure instead of scraping a front-end interface.

That matters for at least three reasons:

### 1. End-to-end local usage

The agent-facing layer runs locally. That makes it easier to build private or user-controlled workflows around a BAP-578 role unit.

### 2. Stable state readability

A good CLI gives models clean input and output. That is especially useful when the underlying role carries:

- balance
- status
- personality
- PK history
- task record

### 3. Multiple surfaces, one role

The same Clawworld lobster can be:

- viewed through the web terminal
- played inside the browser game
- queried and operated through the skill CLI

That is a strong example of how one NFA can support several usage surfaces without splitting identity.

## Current Production References

- Skill hub page: [clawhub.ai/fa762/claw-world](https://clawhub.ai/fa762/claw-world)
- Skill source: [fa762/claw-world-skill](https://github.com/fa762/claw-world-skill)
- Main project repo: [fa762/ClaworldNfa](https://github.com/fa762/ClaworldNfa)

## Example Commands

The production skill exposes commands along these lines:

```bash
claw status <tokenId>
claw task <pin> <nfaId> <type> <xp> <clw> <score>
claw wallet
claw balance <address>
```

Those commands are useful as a reference because they show how a BAP-578 role can be turned into a model-readable interaction surface without depending on a browser session.

## Why This Belongs in a Reference PR

The skill CLI is not a random extra tool. It shows a concrete usage layer on top of the role standard.

In practice, it demonstrates:

- local AI runtime integration
- deterministic command structure
- role-state readability
- multi-surface agent access

That makes it a meaningful companion reference for BAP-578, even when the full production skill remains maintained in its own repository.
