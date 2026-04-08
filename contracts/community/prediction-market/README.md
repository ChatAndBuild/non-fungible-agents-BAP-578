# NFA Prediction Market

A BAP-578 compliant prediction market powered by Non-Fungible Agents, built on BSC.

## Overview

This implementation extends the BAP-578 standard to create AI-powered prediction agents that can autonomously participate in prediction markets on BSC. Each NFA represents an autonomous agent with its own prediction profile, reputation score, and trading authorization.

## Contracts

### NFAPredictionAgent.sol

BAP-578 compliant NFA with prediction-specific extensions:

- **Full BAP-578 Lifecycle** — ACTIVE / PAUSED / TERMINATED state management
- **Prediction Profile** — Tracks total predictions, correct predictions, and computes on-chain reputation score (basis points)
- **Auto-Trade Authorization** — Owners can authorize automated trading with per-trade limits, daily caps, and time-based expiry
- **Learning Module** — Merkle-proof verified on-chain learning data, interaction tracking
- **Memory Module Registry** — Register and verify off-chain knowledge stores per agent
- **Vault Permission Manager** — Tiered delegation (READ_ONLY → FULL_CONTROL) with expiry

### PredictionMarket.sol

BNB-based prediction market with NFA agent integration:

- **Manual & Oracle Resolution** — Supports both admin-resolved and Binance Oracle-resolved markets
- **User-Created Markets** — Community members can create markets with daily rate limiting and creation fees
- **NFA Agent Trading** — `agentTakePosition()` enables NFA agents to autonomously take positions
- **Winner-Takes-Proportional-Share** — Fair payout model where winners receive stake + proportional share of loser pool

### Interfaces

| Interface | Description |
|-----------|-------------|
| `IBAP578` | Core BAP-578 agent lifecycle, metadata, execution, funding |
| `ILearningModule` | On-chain learning with Merkle proof verification |
| `IMemoryModuleRegistry` | Off-chain memory store registration and verification |
| `IVaultPermissionManager` | Tiered vault access delegation with expiry |
| `IBinanceOracle` | Binance Oracle price feed adapter (AggregatorV2V3Interface) |

## Architecture

```
NFAPredictionAgent (ERC721)
├── IBAP578 (core agent standard)
├── ILearningModule (on-chain learning)
├── IMemoryModuleRegistry (memory stores)
└── IVaultPermissionManager (vault delegation)
        │
        ▼
PredictionMarket (BNB)
├── Manual markets (admin)
├── Oracle markets (Binance Oracle)
├── User-created markets (community)
└── agentTakePosition() ← NFA integration
```

## BAP-578 Compliance

| Feature | Status |
|---------|--------|
| ERC-721 base | Implemented |
| Agent state management (active/paused/terminated) | Implemented |
| Structured metadata (persona, voiceHash, animationURI, vault) | Implemented |
| Logic address binding | Implemented |
| Agent funding & withdrawal | Implemented |
| Action execution via logic contract | Implemented |

## How It Works

1. **Mint an NFA** — Pay 0.01 BNB to create a prediction agent with metadata
2. **Fund the Agent** — Deposit BNB to the agent's on-chain balance
3. **Authorize Auto-Trade** — Set per-trade/daily limits and duration
4. **Agent Takes Positions** — The agent autonomously calls `agentTakePosition()` on the prediction market
5. **Learning Updates** — Off-chain AI updates the agent's learning root via Merkle proofs
6. **Claim Rewards** — Winners claim proportional rewards after market resolution

## Tech Stack

- Solidity ^0.8.20
- OpenZeppelin Contracts v5
- BSC (BNB Smart Chain)
- Binance Oracle for price feeds
- BNB for market settlements

## Author

[@saiboyizhan](https://github.com/saiboyizhan)
