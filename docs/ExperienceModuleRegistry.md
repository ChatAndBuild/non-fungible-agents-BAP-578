# Experience Module Registry

## Overview

The Experience Module Registry is a critical component of the BAP-700 Non-Fungible Agent (NFA) ecosystem that allows agents to register and manage external experience sources. This registry provides a secure and flexible way to extend an agent's capabilities without modifying the core contract.

## Purpose

The primary purpose of the ExperienceModuleRegistry is to:

1. Allow agent owners to register approved external experience modules
2. Provide cryptographic verification for module registration
3. Manage approval status for registered modules
4. Store and retrieve metadata for experience modules
5. Enable agents to access a network of specialized experience services

## Contract Architecture

The ExperienceModuleRegistry is implemented as an upgradeable contract with the following key components:

```solidity
contract ExperienceModuleRegistry is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    // BAP700 token contract
    BAP700 public bap700Token;
    
    // Mapping from token ID to registered experience modules
    mapping(uint256 => address[]) private _registeredModules;
    
    // Mapping from token ID to module address to approval status
    mapping(uint256 => mapping(address => bool)) private _approvedModules;
    
    // Mapping from token ID to module address to module metadata
    mapping(uint256 => mapping(address => string)) private _moduleMetadata;

    // Events
    event ModuleRegistered(uint256 indexed tokenId, address indexed moduleAddress, string metadata);
    event ModuleApproved(uint256 indexed tokenId, address indexed moduleAddress, bool approved);
    event ModuleMetadataUpdated(uint256 indexed tokenId, address indexed moduleAddress, string metadata);
    
    // Functions
    function initialize(address _bap700Token) public initializer;
    function registerModule(uint256 tokenId, address moduleAddress, string memory metadata, bytes memory signature) external nonReentrant;
    function setModuleApproval(uint256 tokenId, address moduleAddress, bool approved) external;
    function updateModuleMetadata(uint256 tokenId, address moduleAddress, string memory metadata) external;
    function getRegisteredModules(uint256 tokenId) external view returns (address[] memory);
    function isModuleApproved(uint256 tokenId, address moduleAddress) external view returns (bool);
    function getModuleMetadata(uint256 tokenId, address moduleAddress) external view returns (string memory);
}
```

## Key Features

### Cryptographic Verification

The registry uses cryptographic signatures to verify that module registrations are authorized by the agent owner:

```solidity
// Verify the signature
bytes32 messageHash = keccak256(abi.encodePacked(tokenId, moduleAddress, metadata));
bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
address signer = ethSignedMessageHash.recover(signature);

require(signer == owner, "ExperienceModuleRegistry: invalid signature");
```

### Module Approval Management

Modules can be approved or revoked by the agent owner:

```solidity
function setModuleApproval(
    uint256 tokenId,
    address moduleAddress,
    bool approved
) external {
    // Only the token owner can approve or revoke modules
    require(bap700Token.ownerOf(tokenId) == msg.sender, "ExperienceModuleRegistry: not token owner");
    
    _approvedModules[tokenId][moduleAddress] = approved;
    
    emit ModuleApproved(tokenId, moduleAddress, approved);
}
```

### Metadata Management

Module metadata can be updated by the agent owner:

```solidity
function updateModuleMetadata(
    uint256 tokenId,
    address moduleAddress,
    string memory metadata
) external {
    // Only the token owner can update module metadata
    require(bap700Token.ownerOf(tokenId) == msg.sender, "ExperienceModuleRegistry: not token owner");
    require(_approvedModules[tokenId][moduleAddress], "ExperienceModuleRegistry: module not approved");
    
    _moduleMetadata[tokenId][moduleAddress] = metadata;
    
    emit ModuleMetadataUpdated(tokenId, moduleAddress, metadata);
}
```

## Experience Module Schema

Experience modules are structured as JSON documents that include structured experience layers, custom prompts, and modular behaviors:

```json
{
  "context_id": "nfa700-experience-001",
  "owner": "0xUserWalletAddress",
  "created": "2025-05-12T10:00:00Z",
  "persona": "Strategic crypto analyst",
  "experience_slots": [
    {
      "type": "alert_keywords",
      "data": ["FUD", "rugpull", "hack", "$BNB", "scam"]
    },
    {
      "type": "watchlist",
      "data": ["CZ", "Binance", "Tether", "SEC"]
    },
    {
      "type": "behavior_rules",
      "data": [
        "If sentiment drops >10% in 24h, alert user",
        "If wallet activity spikes, summarize top 5 tokens"
      ]
    }
  ],
  "last_updated": "2025-05-12T11:00:00Z",
  "signed": "0xAgentSig"
}
```

## Usage Examples

### Registering a Experience Module

```javascript
// Create module metadata
const moduleMetadata = JSON.stringify({
  context_id: "nfa700-experience-001",
  owner: ownerAddress,
  created: new Date().toISOString(),
  persona: "Strategic crypto analyst",
  experience_slots: [
    {
      type: "alert_keywords",
      data: ["FUD", "rugpull", "hack", "$BNB", "scam"]
    }
  ]
});

// Create message hash
const messageHash = ethers.utils.solidityKeccak256(
  ["uint256", "address", "string"],
  [tokenId, moduleAddress, moduleMetadata]
);

// Sign the message
const signature = await wallet.signMessage(ethers.utils.arrayify(messageHash));

// Register the module
await experienceRegistry.registerModule(
  tokenId,
  moduleAddress,
  moduleMetadata,
  signature
);
```

### Checking Module Approval

```javascript
// Check if a module is approved
const isApproved = await experienceRegistry.isModuleApproved(tokenId, moduleAddress);

if (isApproved) {
  console.log("Module is approved");
} else {
  console.log("Module is not approved");
}
```

### Retrieving Module Metadata

```javascript
// Get module metadata
const metadata = await experienceRegistry.getModuleMetadata(tokenId, moduleAddress);
const parsedMetadata = JSON.parse(metadata);

console.log("Module persona:", parsedMetadata.persona);
console.log("Alert keywords:", parsedMetadata.experience_slots[0].data);
```

## Security Considerations

### Signature Verification

The registry uses ECDSA signatures to verify that module registrations are authorized by the agent owner. This prevents unauthorized parties from registering modules for an agent.

### Access Control

Only the agent owner can approve or revoke modules and update module metadata. This ensures that the agent owner maintains control over which modules can be used by their agent.

### Reentrancy Protection

The registry uses OpenZeppelin's ReentrancyGuard to protect against reentrancy attacks during module registration.

## Integration with BAP-700 Ecosystem

The Experience Module Registry integrates with the BAP-700 ecosystem in the following ways:

1. **Agent Creation**: When an agent is created, it can register experience modules to extend its capabilities.
2. **Agent Logic**: Agent logic contracts can query the registry to access registered modules.
3. **Agent Upgrades**: When an agent's logic is upgraded, it can register new modules to support new functionality.
4. **Agent Governance**: The governance system can approve or revoke modules based on community decisions.

## Future Extensions

The Experience Module Registry is designed to be extensible and can be enhanced in the following ways:

1. **Module Categories**: Adding support for categorizing modules by functionality.
2. **Module Versioning**: Adding support for versioning modules to track updates.
3. **Module Reputation**: Adding a reputation system for modules based on usage and feedback.
4. **Module Marketplace**: Creating a marketplace for experience modules where developers can offer specialized modules.

## Conclusion

The Experience Module Registry is a powerful component of the BAP-700 ecosystem that enables agents to extend their capabilities through external experience sources. By providing a secure and flexible way to register and manage experience modules, the registry enables agents to evolve and adapt to new use cases without requiring changes to the core contract.
