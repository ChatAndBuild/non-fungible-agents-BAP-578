# PolicyGuard Integration Guide

> How to integrate the Policy Validation Framework into BAP-578 agents

## Overview

The PolicyGuard framework adds an on-chain security layer to BAP-578 NFA agents. It sits between the agent's action proposal and the blockchain, validating every transaction against a composable set of policies.

> **Zero-dependency design**: These interfaces and examples have no dependency on SHLL's AgentNFA, ERC-6551, or ERC-4907. They work with any BAP-578 implementation — just import `IPolicy.sol` and call `validate()`. The `tokenId` parameter is a generic `uint256` that accepts any agent/token ID.

```
Agent proposes action → PolicyGuard.validate() → Policy 1 ✅ → Policy 2 ✅ → ... → Policy N ✅ → Execute
                                                  ↓ (any fail)
                                                  ❌ REVERT — action blocked
```

## Quick Start

### 1. Deploy PolicyGuard

```javascript
// deploy-policyguard.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  // Deploy SpendingLimit policy
  const SpendingLimit = await ethers.getContractFactory("SpendingLimitExample");
  const spendingLimit = await SpendingLimit.deploy();
  await spendingLimit.deployed();
  console.log("SpendingLimit:", spendingLimit.address);

  // Deploy PolicyGuard
  const PolicyGuard = await ethers.getContractFactory("PolicyGuardExample");
  const guard = await PolicyGuard.deploy();
  await guard.deployed();
  console.log("PolicyGuard:", guard.address);

  // Register policy
  await guard.registerPolicy(spendingLimit.address);

  // Bind policy to agent tokenId=1
  await guard.bindPolicies(1, [spendingLimit.address]);

  // Configure spending limit: 0.1 BNB per action
  await spendingLimit.setLimit(1, ethers.utils.parseEther("0.1"));
}

main();
```

### 2. Integrate with BAP578 Contract

To add PolicyGuard validation to the existing `BAP578.sol`, add a `policyGuard` state variable and validate actions before execution:

```solidity
// Add to BAP578.sol state variables:
IPolicyGuard public policyGuard;

// Add setter:
function setPolicyGuard(address _guard) external onlyOwner {
    policyGuard = IPolicyGuard(_guard);
}

// Example: Add policy validation to withdrawFromAgent
function withdrawFromAgent(
    uint256 tokenId,
    uint256 amount
) external onlyTokenOwner(tokenId) nonReentrant {
    require(agentStates[tokenId].balance >= amount, "Insufficient balance");

    // --- PolicyGuard validation ---
    if (address(policyGuard) != address(0)) {
        (bool allowed, string memory reason) = policyGuard.validate(
            address(this),           // nfa
            tokenId,                 // tokenId
            address(this),           // agentAccount
            msg.sender,              // caller
            msg.sender,              // target (withdrawal destination)
            amount,                  // value
            ""                       // no calldata for simple transfer
        );
        require(allowed, reason);
    }

    // Existing logic...
    agentStates[tokenId].balance -= amount;
    emit AgentWithdraw(tokenId, amount);
    (bool success, ) = payable(msg.sender).call{ value: amount }("");
    require(success, "Withdrawal failed");
}
```

### 3. Implement Custom Policies

To create a custom policy, implement the `IPolicy` interface:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./extensions/IPolicy.sol";

contract MyCustomPolicy is IPolicy {
    function check(
        uint256 tokenId,
        address caller,
        address target,
        bytes4 selector,
        bytes calldata callData,
        uint256 value
    ) external view override returns (bool ok, string memory reason) {
        // Your validation logic here
        // Return (true, "") to allow, (false, "reason") to block
    }

    function policyType() external pure override returns (bytes32) {
        return keccak256("my_custom_policy");
    }

    function renterConfigurable() external pure override returns (bool) {
        return false; // only owner can manage
    }
}
```

## Architecture Patterns

### Pattern 1: Pre-execution Validation (View-only)

The `validate()` function is `view` — it reads state but does not modify it. This means:
- Validation can be called without gas cost (off-chain `eth_call`)
- Multiple policies can be checked atomically
- No state corruption risk during validation

### Pattern 2: Post-execution Commit (State-changing)

The `commit()` function is called **after** successful execution to update stateful policies. Example: SpendingLimit tracks cumulative daily spending.

```
validate() → passes → execute action → commit() → update daily counter
```

### Pattern 3: Template/Instance Hierarchy

In SHLL's production system, policies support a template/instance model:
- **Template policies** are set by the agent creator (ceiling)
- **Instance policies** are set by the renter (within ceiling)
- A renter cannot remove non-`renterConfigurable` policies

## Standard Policy Types (4 Core Policies)

| Type ID | Purpose | Example Configuration |
|---|---|---|
| `spending_limit` | Per-action value caps + token whitelist + approve control (V2) | Max 0.1 BNB per swap; only USDT, WBNB allowed |
| `cooldown` | Time intervals | 300 sec between actions |
| `defi_guard` | Contract + function selector filtering (subsumes DEX whitelisting) | Only PancakeSwap V2/V3 `swapExactTokens` allowed |
| `receiver_guard` | Output address whitelist | Only agent vault address allowed |

> **Note**: Earlier designs had separate `dex_whitelist` and `token_whitelist` policies. These are now subsumed by `defi_guard` (target + selector control) and `spending_limit` (token + approve control) respectively.

## Production Reference

For a complete, battle-tested implementation, see SHLL Protocol:

- **PolicyGuardV4**: [BscScan](https://bscscan.com/address/0x25d17eA0e3Bcb8CA08a2BFE917E817AFc05dbBB3)
- **Source Code**: [github.com/shll-protocol/shll](https://github.com/shll-protocol/shll)
- **npm Package**: `npm install -g shll-skills`
