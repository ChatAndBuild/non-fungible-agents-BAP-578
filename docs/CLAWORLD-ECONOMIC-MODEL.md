# Clawworld Economic Model

Clawworld is easier to understand if you picture a bank account system inside a game world.

There are two layers of value moving at the same time.

## Two-Layer Asset Design

### Outside the game — CLW token

The real circulating asset is `CLW` (`0x3b486c191c74c9945fa944a3ddde24acdd63ffff` on BSC mainnet).

That is the token players can hold, trade on DEX, receive, and withdraw to their wallet.

### Inside the game — per-agent balance

Each NFA has its own internal CLW balance recorded on-chain inside ClawRouter. Tasks, PK, Battle Royale, upkeep, dormancy, and role progression all happen against this internal agent account first.

When a player wants to exit value from the role account, the system uses GenesisVault to convert internal balance into the circulating CLW token, subject to available vault liquidity and the current payout ratio.

This is closer to a bank model than a simple reward token model:

- the **external CLW token** is the cash layer
- the **per-agent balance** is the account layer

## Why This Matters

Most game tokens get dumped because players receive them directly and instantly treat them as something to sell.

Clawworld changes that flow.

When value first lands inside an NFA account, players are incentivized to use it: keep the role alive, level it, stake it in PK or Battle Royale, or prepare it for market. That creates internal demand before external sell pressure.

## The Flywheel in Plain Terms

### 1. Players enter

Players spend BNB to mint an NFA (ClawNFA). BNB entry flows through FlapPortal into CLW, seeding vault liquidity.

### 2. Roles produce

The NFA performs tasks (TaskSkill) and earns internal CLW based on role fit, world-state conditions, and personality alignment.

### 3. Roles consume

The same NFA must keep paying upkeep to remain healthy and active. Value does not only flow outward — it keeps cycling back into role maintenance.

### 4. Competitive play applies pressure

**PK** (PKSkill) requires staking internal CLW. Every settled match burns part of the total stake and sends the rest to the winner. Three effects:

- real risk
- real redistribution
- real token removal

**Battle Royale** (BattleRoyale) extends this: 10 players stake CLW into rooms, one random room loses. 10% of losing stake → treasury, 90% → survivors proportionally. Higher stakes, higher tension, more CLW cycling.

### 5. Market circulation restarts the loop

When players buy or sell NFAs (MarketSkill), they are not trading images. They are taking over role accounts with history, personality, stats, balance, and future earning potential. That pushes fresh players back into tasking, upkeep, and competitive play.

## Value Flow Summary

```
BNB mint → FlapPortal → CLW → GenesisVault
                                    │
                            ┌───────┴───────┐
                            ▼               ▼
                      Task rewards    Vault withdrawals
                            │
                            ▼
                    Per-agent balance
                     │     │     │
                     ▼     ▼     ▼
                  Upkeep  PK   Battle Royale
                   (burn) (burn)  (burn→treasury)
                            │
                            ▼
                    Market resale
                    (fee→treasury)
```

Multiple burn and fee channels create steady token removal. The WorldState contract can dynamically tune reward/upkeep/stake multipliers to respond to ecosystem conditions.

## Treasury and Protocol Income

GenesisVault receives income from:

- primary minting (BNB → CLW)
- PK burn share
- Battle Royale losing room treasury cut (10%)
- marketplace fees

This creates a sustainable treasury base for operations and vault support, without pretending value appears from nowhere.

## Why This Is a Useful BAP-578 Example

This model shows a practical way a BAP-578 role unit can become economically thick over time.

The asset is no longer just owned. It is:

- **maintained** — upkeep keeps roles active
- **funded** — internal balance earns and spends
- **risked** — PK and Battle Royale create real loss scenarios
- **priced** — market values history, stats, and earning potential
- **reused** — traded roles re-enter the economy with full state

That is the point where a role unit starts feeling fundamentally different from a thin collectible. And all of this runs on-chain through 11 UUPS-upgradeable contracts on BSC mainnet.
