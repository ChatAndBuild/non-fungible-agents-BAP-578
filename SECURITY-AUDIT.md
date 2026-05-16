# BAP-578 Security Audit Report

**Contract**: `BAP578.sol` (Non-Fungible Agent Token Standard)
**Repository**: [ChatAndBuild/non-fungible-agents-BAP-578](https://github.com/ChatAndBuild/non-fungible-agents-BAP-578)
**Commit**: `main` branch (latest as of 2026-02-10)
**Auditor**: [@lucuixiaobai0819](https://github.com/lucuixiaobai0819)
**Date**: February 10, 2026
**Solidity Version**: 0.8.28
**Framework**: Hardhat + OpenZeppelin Upgradeable Contracts (v4.x)

---

## Executive Summary

This audit covers the reference implementation of the BAP-578 Non-Fungible Agent (NFA) standard. The contract extends ERC-721 with agent state management, structured metadata storage, a free-mint mechanism with soulbound restrictions, and UUPS upgradeability.

**Overall Assessment**: The contract follows good security practices at the function level — Checks-Effects-Interactions pattern in `withdrawFromAgent()`, ReentrancyGuard on state-changing functions with external calls, and soulbound enforcement for free mints. However, the contract has significant **centralization risks** at the architectural level: `emergencyWithdraw()` can drain all user-deposited agent funds, and UUPS upgradeability has no timelock or multisig protection. Users who call `fundAgent()` to deposit ETH are placing complete trust in the contract owner with no on-chain safeguards.

| Severity | Count |
|----------|-------|
| Critical | 2 |
| High | 4 |
| Medium | 3 |
| Low | 4 |
| Informational | 3 |

---

## Critical Findings

### C-01: `emergencyWithdraw()` Can Drain All Agent Funds (Centralization / Rug Pull Vector)

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

**Description**: The owner can withdraw **all ETH** held by the contract via `address(this).balance`, which includes funds deposited by users through `fundAgent()`. Individual agent balances are tracked in `agentStates[tokenId].balance`, but `emergencyWithdraw()` ignores this accounting entirely and sweeps the full contract balance.

**Impact**: Complete loss of all user-deposited agent funds. Any user who calls `fundAgent()` is implicitly trusting the contract owner not to invoke this function.

**Recommendation (Option A — Safest)**: Remove `emergencyWithdraw()` entirely. This function serves no legitimate purpose that cannot be achieved through safer alternatives. User-deposited agent funds should only be withdrawable by the agent's token owner via `withdrawFromAgent()`. If the contract needs a mechanism to recover non-agent funds (e.g., accidentally sent tokens), use a scoped recovery function that cannot touch agent balances.

**Recommendation (Option B — If `emergencyWithdraw()` is kept)**: Introduce a `totalAgentBalances` accumulator that is incremented in `fundAgent()` and decremented in `withdrawFromAgent()`. Restrict emergency withdrawal to unallocated funds only:

```solidity
uint256 public totalAgentBalances;

function emergencyWithdraw() external onlyOwner {
    uint256 unallocated = address(this).balance - totalAgentBalances;
    require(unallocated > 0, "No unallocated balance");
    (bool success, ) = payable(owner()).call{ value: unallocated }("");
    require(success, "Emergency withdraw failed");
}
```

This must be combined with the timelock on UUPS upgrades (see H-04) to be effective — otherwise the owner can simply upgrade the contract to bypass the accounting.

---

### C-02: `emergencyWithdraw()` Permanently Breaks Agent Balance Accounting

**Severity**: Critical
**Location**: `BAP578.sol`, `emergencyWithdraw()` function, `withdrawFromAgent()`, `_burn()`

**Description**: This is a direct consequence of C-01. After `emergencyWithdraw()` is called:

1. `agentStates[tokenId].balance` still reflects positive values, but the actual ETH backing those balances is gone.
2. All subsequent `withdrawFromAgent()` calls will revert because the contract holds no ETH.
3. `_burn()` requires `agentStates[tokenId].balance == 0`, so affected agents can never be burned either — they become permanently stuck.

**Impact**: Permanent state inconsistency. Agent owners lose both their funds and the ability to clean up their tokens.

**Recommendation**: Same fix as C-01. Additionally, if a full emergency drain is truly needed (e.g., contract migration), the function should zero out all affected agent balances to keep state consistent, or the contract should implement a migration pattern allowing users to claim from a new contract.

---

## High Findings

### H-01: `freeMintsPerUser` Change Affects All Existing Users Retroactively

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

**Description**: `freeMintsPerUser` is a global variable used in a real-time calculation. If the owner increases it (e.g., from 3 to 5), **every existing user** — including those who already exhausted their original 3 free mints — instantly receives 2 additional free mints. This creates an uncontrolled token supply inflation vector.

**Impact**: Unintended mass free minting. Could be exploited if owner key is compromised.

**Recommendation**: Snapshot each user's free mint allowance at their first interaction (e.g., store it in a mapping on first mint), or use `grantAdditionalFreeMints()` for targeted increases instead of a global setter.

---

### H-02: Paid Mint Blocked If Treasury Is a Reverting Contract

**Severity**: High
**Location**: `BAP578.sol`, `createAgent()` function

```solidity
(bool success, ) = payable(treasuryAddress).call{ value: msg.value }("");
require(success, "Treasury transfer failed");
```

**Description**: The mint fee is transferred to the treasury inline during `createAgent()`. If `treasuryAddress` is set to a contract whose `receive()`/`fallback()` reverts (intentionally or due to a bug), **all paid mints are blocked** until the owner detects the issue and calls `setTreasury()` to set a new treasury. During this downtime, no paid agents can be created. If the owner key is compromised and the attacker sets treasury to a reverting contract, the DoS becomes permanent.

**Impact**: Denial of service for all paid minting. Severity depends on owner key security.

**Recommendation**: Use a pull-based payment pattern — accumulate fees in the contract and let the treasury claim them via a separate `claimFees()` function. This decouples minting from treasury availability.

---

### H-03: ETH Sent During Free Mint Is Permanently Locked in Contract

**Severity**: High
**Location**: `BAP578.sol`, `createAgent()` function

```solidity
if (freeMintsRemaining > 0) {
    require(to == msg.sender, "Free mints can only be minted to self");
    isFreeMint[_tokenIdCounter + 1] = true;
    freeMintsClaimed[msg.sender]++;
} else {
    require(msg.value == MINT_FEE, "Incorrect fee");
    // ... treasury transfer
}
```

**Description**: When a user has remaining free mints, the code enters the `if` branch and never checks `msg.value`. If a user accidentally sends ETH along with a free mint transaction, the ETH is silently accepted by the contract (the function is `payable`) but never sent to the treasury and never refunded. The ETH becomes permanently locked — there is no mechanism to recover it except `emergencyWithdraw()`, which has the centralization issues described in C-01.

**Impact**: User funds permanently locked. Common user mistake, especially with wallet UIs that allow setting a value.

**Recommendation**: Add `require(msg.value == 0, "Free mint does not require payment")` in the free mint branch.

---

### H-04: UUPS Upgrade Has No Timelock — Owner Can Silently Replace Contract Logic

**Severity**: High
**Location**: `BAP578.sol`, `_authorizeUpgrade()` function

```solidity
function _authorizeUpgrade(address) internal override onlyOwner {}
```

**Description**: The UUPS upgrade authorization only checks `onlyOwner` with no additional safeguards. The owner can call `upgradeTo()` or `upgradeToAndCall()` at any time to replace the entire contract implementation — silently, with no delay, and with no on-chain notice to users. A malicious or compromised owner could upgrade the contract to:

1. Add a function that transfers all agent balances to the owner
2. Modify `withdrawFromAgent()` to revert, locking user funds permanently
3. Remove the soulbound restriction on free-minted tokens
4. Change any business logic without user awareness

This risk is compounded by `fundAgent()`, which allows users to deposit ETH into the contract. Combined with unrestricted upgradeability, **users have zero on-chain guarantees** that the contract logic will remain unchanged after they deposit funds.

**Impact**: Complete negation of smart contract trust assumptions. Users cannot rely on the current code to protect their deposited ETH, as the code can be replaced at any time.

**Recommendation**: Implement a timelock on upgrades (e.g., OpenZeppelin `TimelockController` with a 48-hour minimum delay), transfer ownership to a multisig wallet (e.g., Gnosis Safe), and emit an event announcing pending upgrades so users have time to withdraw funds before any logic change takes effect:

```solidity
event UpgradeScheduled(address indexed newImplementation, uint256 effectiveTime);
```

---

## Medium Findings

### M-01: `tokensOfOwner()` Unbounded Loop May Cause DoS

**Severity**: Medium
**Location**: `BAP578.sol`, `tokensOfOwner()` function

**Description**: The function iterates over all tokens owned by an address. For addresses with many tokens (e.g., a marketplace contract or a whale), this could exceed the block gas limit in an on-chain call or return extremely large results in an off-chain call. The code contains a warning comment but provides no alternative.

**Recommendation**: Add a paginated variant:

```solidity
function tokensOfOwnerPaginated(address account, uint256 offset, uint256 limit)
    external view returns (uint256[] memory)
{
    uint256 tokenCount = balanceOf(account);
    if (offset >= tokenCount) return new uint256[](0);
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

**Description**: Changing `freeMintsPerUser` has a significant impact on minting economics (see H-01), but emits no event. Off-chain monitoring systems, indexers, and users have no way to detect this change without polling the state variable.

**Recommendation**:
```solidity
event FreeMintsPerUserUpdated(uint256 oldAmount, uint256 newAmount);

function setFreeMintsPerUser(uint256 amount) external onlyOwner {
    uint256 old = freeMintsPerUser;
    freeMintsPerUser = amount;
    emit FreeMintsPerUserUpdated(old, amount);
}
```

---

### M-03: No Validation on `metadataURI` and `AgentMetadata` String Lengths

**Severity**: Medium
**Location**: `BAP578.sol`, `createAgent()` and `updateAgentMetadata()`

**Description**: No length validation is performed on `metadataURI`, `persona`, `experience`, `voiceHash`, `animationURI`, or `vaultURI`. Extremely long strings increase gas costs significantly. This is particularly concerning for free mints where the attacker pays no fee — they can store arbitrarily large data on-chain at no cost (except gas, which is relatively cheap on BSC).

**Impact**: Storage griefing. Bloated contract state that increases `eth_getStorageAt` costs for indexers and node operators.

**Recommendation**: Add maximum length checks, especially for free mints:
```solidity
require(bytes(metadataURI).length <= 512, "URI too long");
require(bytes(extendedMetadata.persona).length <= 2048, "Persona too long");
```

---

## Low Findings

### L-01: `MINT_FEE` Is a Compile-Time Constant

**Severity**: Low
**Location**: `BAP578.sol`, `uint256 public constant MINT_FEE = 0.01 ether;`

**Description**: The mint fee cannot be adjusted without a contract upgrade (UUPS). If BNB price increases significantly, 0.01 BNB may become too expensive; if it drops, the fee may become negligible.

**Recommendation**: Consider making it a mutable state variable with an owner-controlled setter and an event.

---

### L-02: `receive()` Reverts But `fallback()` Is Not Defined

**Severity**: Low
**Location**: `BAP578.sol`, `receive()` function

```solidity
receive() external payable {
    revert("Use fundAgent() instead");
}
```

**Description**: Direct ETH transfers revert with a helpful message. However, calls with non-matching calldata and ETH attached will revert with a generic error since no `fallback()` is defined. This is a minor UX issue.

**Recommendation**: Add a `fallback()` with a descriptive revert:
```solidity
fallback() external payable {
    revert("Use fundAgent() to send ETH");
}
```

---

### L-03: `_exists()` Forward-Compatibility with OpenZeppelin v5.x

**Severity**: Low
**Location**: `BAP578.sol`, `fundAgent()`, `getAgentState()`, `getAgentMetadata()`

**Description**: The contract uses `_exists(tokenId)` which is available in OpenZeppelin Contracts v4.x (confirmed by the `_beforeTokenTransfer` hook pattern). However, `_exists()` was removed in v5.x in favor of `_ownerOf(tokenId) != address(0)`. This is not a current issue, but may complicate future dependency upgrades.

**Recommendation**: Pin the OpenZeppelin version in `package.json` with a comment explaining the dependency, or consider using the v5-compatible pattern for forward compatibility.

---

### L-04: No `AgentState` Cleanup After Burn

**Severity**: Low
**Location**: `BAP578.sol`, `_burn()` function

```solidity
function _burn(uint256 tokenId) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
    require(agentStates[tokenId].balance == 0, "Agent balance must be 0");
    super._burn(tokenId);
}
```

**Description**: After burning a token, `agentStates[tokenId]` and `agentMetadata[tokenId]` mappings are not cleared. The stale data remains in storage. While this does not affect correctness (the token no longer exists), it wastes storage and could confuse off-chain indexers that read raw storage.

**Recommendation**: Delete the mappings in the burn function:
```solidity
delete agentStates[tokenId];
delete agentMetadata[tokenId];
```

---

## Informational

### I-01: Test Suite Uses ethers v5 API

The test file uses `ethers.utils.parseEther()`, `ethers.utils.formatBytes32String()`, and `ethers.constants.AddressZero` which are ethers v5 syntax. If the project migrates to ethers v6, these should be updated to `ethers.parseEther()`, `ethers.encodeBytes32String()`, and `ethers.ZeroAddress`.

### I-02: Consider `nonReentrant` on `fundAgent()` for Defense-in-Depth

`fundAgent()` does not make external calls, so reentrancy is not a direct risk. However, adding `nonReentrant` provides defense-in-depth in case future upgrades introduce external calls.

### I-03: Gas Optimization Opportunities

- In `createAgent()`, the `AgentMetadata` struct contains multiple `string` fields. For short, fixed-format data (like `voiceHash`), using `bytes32` instead of `string` would save significant gas on storage.
- `_tokenIdCounter` could be packed with `paused` (bool) into a single storage slot if using a smaller uint type.

---

## Conclusion

The BAP-578 reference implementation demonstrates good function-level security practices — CEI ordering, ReentrancyGuard, and soulbound enforcement. However, the contract has fundamental **centralization and trust issues** that undermine the security of user-deposited funds.

The critical findings (**C-01/C-02**) show that `emergencyWithdraw()` can drain all user-deposited agent funds. The high-severity finding **H-04** reveals that UUPS upgradeability has no timelock or multisig, meaning the owner can silently replace the entire contract logic at any time. Together, these issues mean that **any user who calls `fundAgent()` is placing unconditional trust in the contract owner** — there are no on-chain safeguards protecting deposited ETH.

Before production deployment with user funds, the following should be addressed at minimum:
1. Restrict `emergencyWithdraw()` to unallocated funds only (C-01/C-02)
2. Add a timelock and multisig to UUPS upgrades (H-04)
3. Add `require(msg.value == 0)` in the free mint path (H-03)

The remaining high, medium, and low findings cover economic design risks (retroactive free mint changes, treasury failure), input validation (string lengths, unbounded loops), and standard hardening recommendations.

---

*This audit was conducted as an independent community contribution based on the BAP-578 implementation. It does not constitute financial advice or a guarantee of contract security. A formal audit by a professional security firm is recommended before mainnet deployment with user funds.*
