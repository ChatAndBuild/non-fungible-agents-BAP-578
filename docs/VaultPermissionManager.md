# Vault Permission Manager

## Overview

The Vault Permission Manager is a crucial component of the BAP-700 Non-Fungible Agent (NFA) ecosystem that manages access control for agent vaults. It provides a secure and flexible way for agent owners to delegate access to their agent's off-chain data while maintaining cryptographic verification and time-based controls.

## Purpose

The primary purpose of the VaultPermissionManager is to:

1. Allow agent owners to delegate vault access to specific addresses
2. Implement time-based access control with expiry timestamps
3. Provide cryptographic verification for access requests
4. Enable secure revocation of access when needed
5. Facilitate secure sharing of agent data with authorized third parties

## Contract Architecture

The VaultPermissionManager is implemented as an upgradeable contract with the following key components:

```solidity
contract VaultPermissionManager is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    // BAP700 token contract
    BAP700 public bap700Token;
    
    // Mapping from token ID to delegated addresses
    mapping(uint256 => mapping(address => bool)) private _delegatedAccess;
    
    // Mapping from token ID to delegation expiry timestamps
    mapping(uint256 => mapping(address => uint256)) private _delegationExpiry;
    
    // Events
    event AccessDelegated(uint256 indexed tokenId, address indexed delegate, uint256 expiryTime);
    event AccessRevoked(uint256 indexed tokenId, address indexed delegate);
    event VaultAccessRequested(uint256 indexed tokenId, address indexed requester, bytes32 requestId);
    event VaultAccessGranted(uint256 indexed tokenId, address indexed requester, bytes32 requestId);
    
    // Functions
    function initialize(address _bap700Token) public initializer;
    function delegateAccess(uint256 tokenId, address delegate, uint256 expiryTime, bytes memory signature) external nonReentrant;
    function revokeAccess(uint256 tokenId, address delegate) external;
    function requestVaultAccess(uint256 tokenId) external returns (bytes32 requestId);
    function grantVaultAccess(uint256 tokenId, address requester, bytes32 requestId, bytes memory signature) external;
    function hasVaultAccess(uint256 tokenId, address delegate) external view returns (bool);
    function getDelegationExpiry(uint256 tokenId, address delegate) external view returns (uint256);
}
```

## Key Features

### Cryptographic Verification

The manager uses cryptographic signatures to verify that access delegations are authorized by the agent owner:

```solidity
// Verify the signature
bytes32 messageHash = keccak256(abi.encodePacked(tokenId, delegate, expiryTime));
bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
address signer = ethSignedMessageHash.recover(signature);

require(signer == owner, "VaultPermissionManager: invalid signature");
```

### Time-Based Access Control

Access delegations include an expiry timestamp to limit the duration of access:

```solidity
require(expiryTime > block.timestamp, "VaultPermissionManager: expiry time in the past");

// Grant access
_delegatedAccess[tokenId][delegate] = true;
_delegationExpiry[tokenId][delegate] = expiryTime;
```

### Access Revocation

Access can be revoked at any time by the agent owner:

```solidity
function revokeAccess(
    uint256 tokenId,
    address delegate
) external {
    // Only the token owner can revoke access
    require(bap700Token.ownerOf(tokenId) == msg.sender, "VaultPermissionManager: not token owner");
    
    _delegatedAccess[tokenId][delegate] = false;
    _delegationExpiry[tokenId][delegate] = 0;
    
    emit AccessRevoked(tokenId, delegate);
}
```

### Access Request System

The manager includes a request-grant system for vault access:

```solidity
function requestVaultAccess(uint256 tokenId) 
    external 
    returns (bytes32 requestId) 
{
    // Generate a unique request ID
    requestId = keccak256(abi.encodePacked(tokenId, msg.sender, block.timestamp));
    
    emit VaultAccessRequested(tokenId, msg.sender, requestId);
    
    return requestId;
}

function grantVaultAccess(
    uint256 tokenId,
    address requester,
    bytes32 requestId,
    bytes memory signature
) external {
    // Verify that the token exists
    require(bap700Token.ownerOf(tokenId) != address(0), "VaultPermissionManager: token does not exist");
    
    // Get the owner of the token
    address owner = bap700Token.ownerOf(tokenId);
    
    // Verify the signature
    bytes32 messageHash = keccak256(abi.encodePacked(tokenId, requester, requestId));
    bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
    address signer = ethSignedMessageHash.recover(signature);
    
    require(signer == owner, "VaultPermissionManager: invalid signature");
    
    emit VaultAccessGranted(tokenId, requester, requestId);
}
```

## Vault Structure

Agent vaults are structured as encrypted JSON documents that contain sensitive agent data:

```json
{
  "vault_id": "nfa700-vault-001",
  "owner": "0xUserWalletAddress",
  "created": "2025-05-12T10:00:00Z",
  "encrypted_sections": {
    "api_keys": {
      "cipher": "aes-256-gcm",
      "data": "encrypted_data_here",
      "iv": "initialization_vector_here",
      "tag": "authentication_tag_here"
    },
    "private_experience": {
      "cipher": "aes-256-gcm",
      "data": "encrypted_data_here",
      "iv": "initialization_vector_here",
      "tag": "authentication_tag_here"
    },
    "credentials": {
      "cipher": "aes-256-gcm",
      "data": "encrypted_data_here",
      "iv": "initialization_vector_here",
      "tag": "authentication_tag_here"
    }
  },
  "access_log": [
    {
      "delegate": "0xDelegateAddress",
      "timestamp": "2025-05-13T14:30:00Z",
      "sections": ["api_keys"]
    }
  ],
  "last_updated": "2025-05-13T14:30:00Z"
}
```

## Usage Examples

### Delegating Vault Access

```javascript
// Set expiry time (1 day from now)
const expiryTime = Math.floor(Date.now() / 1000) + 86400;

// Create message hash
const messageHash = ethers.utils.solidityKeccak256(
  ["uint256", "address", "uint256"],
  [tokenId, delegateAddress, expiryTime]
);

// Sign the message
const signature = await wallet.signMessage(ethers.utils.arrayify(messageHash));

// Delegate access
await vaultManager.delegateAccess(
  tokenId,
  delegateAddress,
  expiryTime,
  signature
);
```

### Checking Vault Access

```javascript
// Check if an address has access to a vault
const hasAccess = await vaultManager.hasVaultAccess(tokenId, delegateAddress);

if (hasAccess) {
  console.log("Address has vault access");
} else {
  console.log("Address does not have vault access");
}
```

### Revoking Vault Access

```javascript
// Revoke access
await vaultManager.revokeAccess(tokenId, delegateAddress);
console.log("Access revoked");
```

### Requesting and Granting Vault Access

```javascript
// Request access
const requestId = await vaultManager.requestVaultAccess(tokenId);

// Owner signs the request
const messageHash = ethers.utils.solidityKeccak256(
  ["uint256", "address", "bytes32"],
  [tokenId, requesterAddress, requestId]
);
const signature = await ownerWallet.signMessage(ethers.utils.arrayify(messageHash));

// Grant access
await vaultManager.grantVaultAccess(
  tokenId,
  requesterAddress,
  requestId,
  signature
);
```

## Security Considerations

### Signature Verification

The manager uses ECDSA signatures to verify that access delegations and grants are authorized by the agent owner. This prevents unauthorized parties from gaining access to agent vaults.

### Time-Based Expiry

Access delegations include an expiry timestamp to limit the duration of access. This ensures that access is automatically revoked after a specified time period.

### Access Revocation

The agent owner can revoke access at any time, providing an additional layer of control over vault access.

### Reentrancy Protection

The manager uses OpenZeppelin's ReentrancyGuard to protect against reentrancy attacks during access delegation.

## Integration with BAP-700 Ecosystem

The Vault Permission Manager integrates with the BAP-700 ecosystem in the following ways:

1. **Agent Creation**: When an agent is created, its vault URI and hash are stored in the agent's metadata.
2. **Agent Logic**: Agent logic contracts can use the vault to store sensitive data needed for operation.
3. **Experience Modules**: Experience modules can access the vault to retrieve or store data with proper authorization.
4. **Agent Governance**: The governance system can set policies for vault access and delegation.

## Use Cases

### Secure API Key Management

Agents often need to interact with external APIs that require authentication. The vault can securely store API keys and credentials, and the permission manager can control which services can access these credentials.

### Private Experience Storage

Agents may accumulate private experience that should not be publicly accessible. The vault can store this private experience, and the permission manager can control who can access it.

### Collaborative Agent Development

Multiple developers may need access to an agent's data during development. The permission manager allows the agent owner to delegate temporary access to collaborators without sharing ownership of the agent.

### Service Integration

Third-party services may need access to agent data to provide specialized functionality. The permission manager allows the agent owner to grant limited access to these services.

## Future Extensions

The Vault Permission Manager is designed to be extensible and can be enhanced in the following ways:

1. **Granular Access Control**: Adding support for granting access to specific sections of the vault.
2. **Multi-Signature Approval**: Requiring multiple signatures for high-value vault access.
3. **Access Logs**: Recording all access attempts and successful accesses for audit purposes.
4. **Conditional Access**: Implementing conditions that must be met for access to be granted.

## Conclusion

The Vault Permission Manager is a powerful component of the BAP-700 ecosystem that enables secure and flexible access control for agent vaults. By providing cryptographic verification, time-based controls, and revocation capabilities, the manager ensures that agent owners maintain control over their agent's sensitive data while enabling collaboration and service integration.
