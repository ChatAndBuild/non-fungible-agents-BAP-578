# Security: Policy Validation Framework for BAP-578

> Contributed by [SHLL Protocol](https://github.com/kledx/shll)

## Overview

This document describes the security architecture for policy-enforced AI agent actions on BAP-578 NFA tokens. The framework extends BAP-578 §4.7 (Security Mechanisms) with **granular, on-chain, per-transaction policy enforcement**.

## Threat Model

AI agents operating autonomously on-chain face attack vectors that traditional Web3 security does not address:

| Threat | Description | Impact |
|---|---|---|
| **Model Hallucination** | LLM generates incorrect parameters (wrong token address, extreme slippage, excessive amounts) | Irreversible loss of funds |
| **Prompt Injection** | Malicious data sources trick the agent into executing unauthorized transfers | Funds redirected to attacker |
| **Supply Chain Attack** | Compromised npm/pip dependency alters transaction payloads before signing | Silent fund theft |
| **Operator Key Compromise** | Attacker gains access to the AI agent's execution key | Full access to agent funds |

**Key insight**: All four attack vectors originate in the off-chain environment (LLM, runtime, dependencies). The only defense that cannot be bypassed is **on-chain smart contract enforcement**.

## Four Core Policies

The PolicyGuard framework defines **four core policy types**. Each policy validates a single aspect of an action:

| Layer | Policy Type | What It Blocks | Fail-Close Behavior |
|---|---|---|---|
| 1 | **SpendingLimit** | Transactions exceeding per-action or daily caps; also integrates token whitelist + approve control in production V2 | No limit configured → block |
| 2 | **Cooldown** | Rapid-fire transactions (bot loops, gas drain) | Cooldown not elapsed → block |
| 3 | **DeFiGuard** | Calls to non-approved contracts or function selectors; subsumes DEX router whitelisting | Unknown target/selector → block |
| 4 | **ReceiverGuard** | Transfers to non-whitelisted addresses | No whitelist → block |

> **Design note**: Earlier iterations included separate `DexWhitelist` and `TokenWhitelist` policies. These were consolidated — `DeFiGuard` subsumes DEX router whitelisting (target + selector), and `SpendingLimitV2` integrates token whitelist + approve control. Four policies provide complete coverage with less administrative overhead.

### Fail-Close Design

All policies follow **fail-close** semantics:
- If a policy contract reverts → action is **BLOCKED**
- If a policy returns `ok=false` → action is **BLOCKED**
- If no policies are bound → action is **BLOCKED**
- Only explicit `ok=true` from **ALL** bound policies permits execution

There is no "default allow." The system fails safe, always.

## Security Architecture: Dual-Wallet Model

```
┌─────────────────────────────┐
│         Owner Wallet        │  ← User-controlled
│  • Holds NFA token          │  • Sets policies
│  • Full admin rights        │  • Withdraws funds
│  • Cannot be overridden     │  • Pauses agent
└────────────┬────────────────┘
             │ owns
┌────────────▼────────────────┐
│       AgentAccount          │  ← Smart contract vault
│  • Isolated fund storage    │     (ERC-6551 TBA)
│  • PolicyGuard enforced     │
│  • All actions validated    │
└────────────┬────────────────┘
             │ executes through
┌────────────▼────────────────┐
│      Operator Wallet        │  ← AI-controlled
│  • Can only propose actions │  • Cannot transfer funds out
│  • Cannot modify policies   │  • Cannot self-destruct
│  • Subject to ALL policies  │  • Cannot bypass PolicyGuard
└─────────────────────────────┘
```

**Key property**: The AI agent (operator) can only propose actions. The smart contract (PolicyGuard) decides whether to execute them. Even if the operator key is fully compromised, the attacker is still bound by all on-chain policies.

## Security Checklist

### Smart Contract Security

- [x] **Reentrancy protection** — All state changes before external calls (CEI pattern)
- [x] **Access control** — Owner-only administrative functions
- [x] **Input validation** — Zero-address checks, array bounds
- [x] **Fail-close by default** — Unconfigured agents cannot execute actions
- [x] **No delegatecall** — Policies cannot execute arbitrary code
- [x] **View-only validation** — `validate()` is `view`, cannot modify state during check
- [x] **Composable isolation** — Each policy is an independent contract

### Known Limitations (Resolved)

> **SpendingLimitPolicyV2: Daily Cap (`maxPerDay`) — FIXED**
>
> **Severity**: Medium | **Status**: ✅ Fixed
>
> **Previous issue**: The `onCommit()` function only tracked `msg.value` (native BNB) toward the daily cap. For ERC20→ERC20 swaps using `approve` + `swap` flow, `value=0` bypassed daily accumulation.
>
> **Fix**: Added `_extractSpendAmount()` helper that parses `amountIn` from swap calldata using the existing `OutputPattern` registry. Both `check()` and `onCommit()` now enforce daily caps against native BNB **and** ERC20 swap amounts. Supports V2 5-param, V3 single, and V3 multi swap layouts.
>
> **Test coverage**: 54/54 SpendingLimit tests pass including 2 new ERC20 swap daily limit test cases. Full suite: 278/278 tests pass.
>
> **Design note**: `amountIn` for ERC20 swaps is in token-native denomination, not BNB. The daily cap serves as a velocity limiter rather than an exact BNB-equivalent budget. Combined with `CooldownPolicy`, this provides effective rate limiting.

### Operational Security

- [x] **Owner/Operator separation** — AI never holds the ownership key
- [x] **On-chain enforcement** — All policies enforced at smart contract level
- [x] **Auditable trail** — Events emitted for every validation and execution
- [x] **Emergency controls** — Agent can be paused via state toggle

## Production Deployment (BSC Mainnet)

SHLL Protocol maintains the production reference implementation with **12 verified contracts** on BSC Mainnet (Chain ID: 56):

| Contract | Address | Purpose |
|---|---|---|
| AgentNFA (V4.1) | [`0x71cE46099E4b2a2434111C009A7E9CFd69747c8E`](https://bscscan.com/address/0x71cE46099E4b2a2434111C009A7E9CFd69747c8E) | BAP-578 core: agent identity & lifecycle |
| PolicyGuardV4 | [`0x25d17eA0e3Bcb8CA08a2BFE917E817AFc05dbBB3`](https://bscscan.com/address/0x25d17eA0e3Bcb8CA08a2BFE917E817AFc05dbBB3) | Policy validation engine |
| SpendingLimitPolicyV2 | [`0x28efC8D513D44252EC26f710764ADe22b2569115`](https://bscscan.com/address/0x28efC8D513D44252EC26f710764ADe22b2569115) | Per-action/daily caps |
| CooldownPolicy | [`0x0E0B2006DE4d68543C4069249a075C215510efDB`](https://bscscan.com/address/0x0E0B2006DE4d68543C4069249a075C215510efDB) | Time intervals |
| ReceiverGuardPolicyV2 | [`0x7A9618ec6c2e9D93712326a7797A829895c0AfF6`](https://bscscan.com/address/0x7A9618ec6c2e9D93712326a7797A829895c0AfF6) | Address whitelist |
| DeFiGuardPolicyV2 | [`0xD1b6a97400Bc62ed6000714E9810F36Fc1a251f1`](https://bscscan.com/address/0xD1b6a97400Bc62ed6000714E9810F36Fc1a251f1) | Function filtering |
| DexWhitelistPolicy | [`0x0D423290A050187AA15B7567aa9DB32535cEF8fb`](https://bscscan.com/address/0x0D423290A050187AA15B7567aa9DB32535cEF8fb) | DEX router whitelist |
| TokenWhitelistPolicy | [`0x4300e2111DB1DB41d74C98fAde2DB432DceF4dBA`](https://bscscan.com/address/0x4300e2111DB1DB41d74C98fAde2DB432DceF4dBA) | Token whitelist |

### Test Coverage

- **278 / 278 Foundry test cases passing** (100% pass rate)
- Test suite covers: policy validation, fail-close behavior, edge cases, access control, reentrancy
- All contracts verified on BscScan with source code published

### Audit Status

- Internal security review completed
- All contracts are open source: [github.com/kledx/shll](https://github.com/kledx/shll)
- Community audit welcome — issues can be reported via GitHub

## Standards Compliance

| Standard | Usage |
|---|---|
| **BAP-578** | Non-Fungible Agent Token Standard — agent identity and lifecycle |
| **ERC-6551** | Token Bound Accounts — isolated per-agent fund vaults |
| **ERC-4907** | Rentable NFT — time-limited agent leasing |
| **ERC-8004** | On-chain Agent Identity Registry — discoverability |

## Links

- **Production**: [shll.run](https://shll.run)
- **Source Code**: [github.com/kledx/shll](https://github.com/kledx/shll)
- **npm Package**: [shll-skills](https://www.npmjs.com/package/shll-skills) (CLI + MCP Server)
- **Twitter**: [@shllrun](https://twitter.com/shllrun)
