# BAP-578 Security Audit Report

**Contract**: `BAP578.sol` (Non-Fungible Agent Token Standard)
**Repository**: [ChatAndBuild/non-fungible-agents-BAP-578](https://github.com/ChatAndBuild/non-fungible-agents-BAP-578)
**Commit**: `main` branch (latest as of 2026-02-10)
**Auditor**: [@lucuixiaobai0819](https://github.com/lucuixiaobai0819)
**Date**: February 10, 2026
**Solidity Version**: 0.8.28
**Framework**: Hardhat + OpenZeppelin Upgradeable Contracts

---

## Executive Summary

This audit covers the reference implementation of the BAP-578 Non-Fungible Agent (NFA) standard. The contract extends ERC-721 with agent state management, metadata storage, a free-mint mechanism, and UUPS upgradeability.

**Overall Assessment**: The contract follows good security practices (Checks-Effects-Interactions pattern, ReentrancyGuard, UUPS). However, several issues were identified ranging from critical fund safety concerns to medium-severity logic bugs.

| Severity | Count |
|----------|-------|
| Critical | 2 |
| High | 3 |
| Medium | 4 |
| Low | 3 |
| Informational | 3 |

---

## Critical Findings

### C-01: `emergencyWithdraw()` Can Drain All Agent Funds (Rug Pull Vector)

**Severity**: Critical
**Location**: `BAP578.sol`, `emergencyWithdraw()` function

```solidity
function emergencyWithdraw() external onlyOwner {
    uint256 balance = address(this).balance;
    require(balance > 0, "No balance");
    (bool success, ) = payable(owner()).call{ value: balance }("");
    require(success, "Emergency withdraw failed");
}
```

**Description**: The owner can withdraw **all ETH** held by the contract, including funds that belong to individual agents (stored in `agentStates[tokenId].balance`). This is a centralization risk — users who fund their agents have no protection against the contract owner draining their deposits.

**Impact**: Complete loss of all agent-held funds. Users who call `fundAgent()` are trusting the contract owner entirely.

**Recommendation**:
1. Track the total of all agent balances in a state variable.
2. Only allow emergency withdrawal of funds **not** allocated to agents.

```solidity
uint256 public totalAgentBalances;

function emergencyWithdraw() external onlyOwner {
    uint256 unallocated = address(this).balance - totalAgentBalances;
    require(unallocated > 0, "No unallocated balance");
    (bool success, ) = payable(owner()).call{ value: unallocated }("");
    require(success, "Emergency withdraw failed");
}
```

Update `fundAgent` and `withdrawFromAgent` to maintain `totalAgentBalances`.

---

### C-02: `emergencyWithdraw()` Breaks Agent Balance Accounting

**Severity**: Critical
**Location**: `BAP578.sol`, `emergencyWithdraw()` function

**Description**: After `emergencyWithdraw()` is called, `agentStates[tokenId].balance` still shows positive balances, but the actual ETH is gone. Agent owners calling `withdrawFromAgent()` will fail because the contract has no ETH. The state mapping becomes permanently inconsistent with reality.

**Impact**: Agent owners are permanently unable to withdraw their funds. The `_burn` function requires `balance == 0`, so agents with drained balances can never be burned either.

**Recommendation**: If emergency withdrawal is needed, it should iterate through agents and set their balances to zero, or implement the unallocated-only approach from C-01.

---

## High Findings

### H-01: No Reentrancy Guard on `fundAgent()`

**Severity**: High
**Location**: `BAP578.sol`, `fundAgent()` function

```solidity
function fundAgent(uint256 tokenId) external payable whenNotPaused {
    require(_exists(tokenId), "Token does not exist");
    agentStates[tokenId].balance += msg.value;
    emit AgentFunded(tokenId, msg.value);
}
```

**Description**: Unlike `withdrawFromAgent()` and `createAgent()`, the `fundAgent()` function is not protected by `nonReentrant`. While `fundAgent` itself doesn't make external calls, a malicious contract could use a reentrancy path through `createAgent` (which calls `_safeMint` → ERC721 `onERC721Received` callback) to manipulate state during funding.

**Recommendation**: Add `nonReentrant` modifier for defense-in-depth.

---

### H-02: `freeMintsPerUser` Change Affects Existing Users Retroactively

**Severity**: High
**Location**: `BAP578.sol`, `setFreeMintsPerUser()` and `getFreeMints()`

```solidity
function setFreeMintsPerUser(uint256 amount) external onlyOwner {
    freeMintsPerUser = amount;
}

function getFreeMints(address user) external view returns (uint256) {
    uint256 totalFreeMints = freeMintsPerUser + bonusFreeMints[user];
    uint256 claimed = freeMintsClaimed[user];
    return claimed >= totalFreeMints ? 0 : totalFreeMints - claimed;
}
```

**Description**: If the owner reduces `freeMintsPerUser` (e.g., from 3 to 1), users who already claimed 2 free mints would appear to have 0 remaining, which is correct. However, if the owner **increases** it (e.g., from 3 to 5), **all existing users** suddenly get additional free mints, even those who already used their original allocation. This creates an uncontrolled token dilution vector.

**Recommendation**: Snapshot the free mint allowance per user at first interaction, or only allow increasing, never decreasing.

---

### H-03: Paid Mint Fee Sent to Treasury Can Fail Silently on Contract Treasury

**Severity**: High
**Location**: `BAP578.sol`, `createAgent()` function

```solidity
require(msg.value == MINT_FEE, "Incorrect fee");
require(treasuryAddress != address(0), "Treasury not set");
(bool success, ) = payable(treasuryAddress).call{ value: msg.value }("");
require(success, "Treasury transfer failed");
```

**Description**: If `treasuryAddress` is a contract that reverts on `receive()` or has a fallback that consumes excessive gas, all paid mints will permanently fail. There is no fallback mechanism, and the owner must call `setTreasury()` to fix this. During downtime, no paid mints can be executed.

**Recommendation**: Consider using a pull-based payment pattern (accumulate fees in the contract, treasury claims later), or implement a fallback treasury address.

---

## Medium Findings

### M-01: `tokensOfOwner()` Unbounded Loop May Cause DoS

**Severity**: Medium
**Location**: `BAP578.sol`, `tokensOfOwner()` function

**Description**: The function iterates over all tokens owned by an address. For addresses with many tokens, this could exceed the block gas limit, making the function unusable. The code contains a comment warning about this but provides no alternative.

**Recommendation**: Add pagination support:

```solidity
function tokensOfOwner(address account, uint256 offset, uint256 limit)
    external view returns (uint256[] memory)
{
    uint256 tokenCount = balanceOf(account);
    uint256 end = offset + limit > tokenCount ? tokenCount : offset + limit;
    uint256[] memory tokens = new uint256[](end - offset);
    for (uint256 i = offset; i < end; i++) {
        tokens[i - offset] = tokenOfOwnerByIndex(account, i);
    }
    return tokens;
}
```

---

### M-02: Missing Event Emission in `setFreeMintsPerUser()`

**Severity**: Medium
**Location**: `BAP578.sol`, `setFreeMintsPerUser()` function

```solidity
function setFreeMintsPerUser(uint256 amount) external onlyOwner {
    freeMintsPerUser = amount;
}
```

**Description**: Changing `freeMintsPerUser` has a significant impact on the minting economics, but emits no event. Off-chain monitoring systems and users cannot detect this change.

**Recommendation**: Add an event:
```solidity
event FreeMintsPerUserUpdated(uint256 oldAmount, uint256 newAmount);
```

---

### M-03: `_exists()` Is Deprecated in Newer OpenZeppelin Versions

**Severity**: Medium
**Location**: `BAP578.sol`, multiple functions

**Description**: The contract uses `_exists(tokenId)` which is deprecated in OpenZeppelin Contracts v5.x. If the project upgrades dependencies, this will cause compilation errors.

**Recommendation**: Use `_ownerOf(tokenId) != address(0)` instead, or pin the OpenZeppelin version with a clear comment.

---

### M-04: No Validation on `metadataURI` and `AgentMetadata` Strings

**Severity**: Medium
**Location**: `BAP578.sol`, `createAgent()` function

**Description**: No length or format validation on `metadataURI`, `persona`, `experience`, `voiceHash`, `animationURI`, or `vaultURI`. Extremely long strings would increase gas costs significantly and could be used as a griefing vector (especially during free mints where the attacker pays no fee).

**Recommendation**: Add maximum length checks for string parameters, especially for free mints.

---

## Low Findings

### L-01: `MINT_FEE` Is Immutable

**Severity**: Low
**Location**: `BAP578.sol`, line `uint256 public constant MINT_FEE = 0.01 ether;`

**Description**: The mint fee is a compile-time constant. If BNB price changes significantly, the fee cannot be adjusted without a contract upgrade.

**Recommendation**: Consider making it a mutable state variable with an owner setter.

---

### L-02: `receive()` Reverts But `fallback()` Is Not Defined

**Severity**: Low
**Location**: `BAP578.sol`, `receive()` function

**Description**: The `receive()` function reverts with "Use fundAgent() instead", which is good. However, `fallback()` is not defined. If someone sends ETH with calldata that doesn't match any function, it will revert with a less descriptive error.

**Recommendation**: Add a `fallback()` with a descriptive revert for consistency.

---

### L-03: Free-Minted Tokens Cannot Be Burned

**Severity**: Low
**Location**: `BAP578.sol`, `_beforeTokenTransfer()`

```solidity
if (isFreeMint[tokenId]) {
    require(
        from == address(0) || to == address(0),
        "Free minted tokens are non-transferable"
    );
}
```

**Description**: The check allows transfers to `address(0)` (burn), but `_burn()` requires `agentStates[tokenId].balance == 0`. If an agent's state is deleted or the balance mapping is cleared via upgrade, the burn check may behave unexpectedly.

**Recommendation**: Ensure the burn path is tested and documented for free-minted tokens.

---

## Informational

### I-01: Test Suite Uses Deprecated `ethers.utils` API

The test file uses `ethers.utils.parseEther()` and `ethers.utils.formatBytes32String()` which are ethers v5 syntax. The tests should be updated if the project migrates to ethers v6.

### I-02: No Constructor Guard for Implementation Contract

While `_disableInitializers()` is called in the constructor, consider adding NatSpec comments explaining the UUPS upgrade pattern for future contributors.

### I-03: Missing Gas Optimization

In `createAgent()`, `_tokenIdCounter` is read and incremented with prefix `++`. The state variable could be packed more efficiently, and the `AgentMetadata` struct could use `bytes32` for short strings instead of `string` to save gas.

---

## Conclusion

The BAP-578 reference implementation demonstrates a solid foundation for the NFA standard with good use of OpenZeppelin security primitives. The most critical finding (**C-01/C-02**) relates to `emergencyWithdraw()` being able to drain user-deposited agent funds without accounting, which represents a significant trust assumption.

The high-severity findings relate to economic design (free mint retroactivity) and operational risks (treasury failure blocking mints). Addressing these issues would significantly improve the contract's trustworthiness for production deployment.

---

*This audit was conducted as an independent community contribution. It does not constitute financial advice or a guarantee of contract security. A formal audit by a professional security firm is recommended before mainnet deployment.*
